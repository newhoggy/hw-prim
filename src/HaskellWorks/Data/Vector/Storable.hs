{-# LANGUAGE BangPatterns        #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE ScopedTypeVariables #-}

module HaskellWorks.Data.Vector.Storable
  ( padded
  , foldMap
  , mapAccumL
  , mmap
  , constructSI
  , construct2N
  ) where

import Control.Monad.ST     (ST, runST)
import Data.Monoid          (Monoid (..), (<>))
import Data.Vector.Storable (Storable)
import Data.Word
import Foreign.ForeignPtr
import Prelude              hiding (foldMap)

import qualified Data.Vector.Generic          as DVG
import qualified Data.Vector.Storable         as DVS
import qualified Data.Vector.Storable.Mutable as DVSM
import qualified System.IO.MMap               as IO

{-# ANN module ("HLint: ignore Redundant do"        :: String) #-}

padded :: Int -> DVS.Vector Word8 -> DVS.Vector Word8
padded n v = v <> DVS.replicate ((n - DVS.length v) `max` 0) 0
{-# INLINE padded #-}

foldMap :: (DVS.Storable a, Monoid m) => (a -> m) -> DVS.Vector a -> m
foldMap f = DVS.foldl' (\a b -> a <> f b) mempty
{-# INLINE foldMap #-}

mapAccumL :: forall a b c. (Storable b, Storable c)
  => (a -> b -> (a, c))
  -> a
  -> DVS.Vector b
  -> (a, DVS.Vector c)
mapAccumL f a vb = DVS.createT $ do
  vc <- DVSM.unsafeNew (DVS.length vb)
  a' <- go 0 a vc
  return (a', vc)
  where go :: Int -> a -> DVS.MVector s c -> ST s a
        go i a0 vc = if i < DVS.length vb
          then do
            let (a1, c1) = f a0 (DVS.unsafeIndex vb i)
            DVSM.unsafeWrite vc i c1
            go (i + 1) a1 vc
          else return a0
{-# INLINE mapAccumL #-}

-- | MMap the file as a storable vector.  If the size of the file is not a multiple of the element size
-- in bytes, then the last few bytes of the file will not be included in the vector.
mmap :: Storable a => FilePath -> IO (DVS.Vector a)
mmap filepath = do
  (fptr :: ForeignPtr Word8, offset, size) <- IO.mmapFileForeignPtr filepath IO.ReadOnly Nothing
  let !v = DVS.unsafeFromForeignPtr fptr offset size
  return (DVS.unsafeCast v)

-- | Construct a vector statefully with index
constructSI :: forall a s. Storable a => Int -> (Int -> s -> (s, a)) -> s -> (s, DVS.Vector a)
constructSI n f state = DVS.createT $ do
  mv <- DVSM.unsafeNew n
  state' <- go 0 state mv
  return (state', mv)
  where go :: Int -> s -> DVSM.MVector t a -> ST t s
        go i s mv = if i < DVSM.length mv
          then do
            let (s', a) = f i s
            DVSM.unsafeWrite mv i a
            go (i + 1) s' mv
          else return s

construct2N :: (Storable b, Storable c)
  => Int
  -> (forall s. a -> DVSM.MVector s b -> ST s Int)
  -> Int
  -> (forall s. a -> DVSM.MVector s c -> ST s Int)
  -> [a]
  -> (DVS.Vector b, DVS.Vector c)
construct2N nb fb nc fc as = runST $ do
  mbs <- DVSM.unsafeNew nb
  mcs <- DVSM.unsafeNew nc
  (mbs2, mcs2) <- go fb 0 mbs fc 0 mcs as
  bs <- DVG.unsafeFreeze mbs2
  cs <- DVG.unsafeFreeze mcs2
  return (bs, cs)
  where go :: (Storable b, Storable c)
          => (forall t. a -> DVSM.MVector t b -> ST t Int)
          -> Int
          -> DVSM.MVector s b
          -> (forall t. a -> DVSM.MVector t c -> ST t Int)
          -> Int
          -> DVSM.MVector s c
          -> [a]
          -> ST s (DVSM.MVector s b, DVSM.MVector s c)
        go   _ bn mbs   _ cn mcs []     = return (DVSM.take bn mbs, DVSM.take cn mcs)
        go fb' bn mbs fc' cn mcs (d:ds) = do
          bi <- fb' d (DVSM.drop bn mbs)
          ci <- fc' d (DVSM.drop cn mcs)
          go fb' (bn + bi) mbs fc' (cn + ci) mcs ds
