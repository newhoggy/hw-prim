{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE FlexibleInstances   #-}
{-# LANGUAGE Rank2Types          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections       #-}

module HaskellWorks.Data.Vector.AsVector8ns
  ( AsVector8ns(..)
  ) where

import Control.Applicative ((<$>))
import Control.Monad.ST
import Data.Word
import Foreign.ForeignPtr
-- import HaskellWorks.Data.ByteString (ToByteString (..))
import HaskellWorks.Data.Vector.AsVector8

import qualified Data.ByteString              as BS
import qualified Data.ByteString.Internal     as BS
import qualified Data.ByteString.Lazy         as LBS
import qualified Data.Vector.Storable         as DVS
import qualified Data.Vector.Storable.Mutable as DVSM

class AsVector8ns a where
  -- | Represent the value as a list of Vector of 'n' Word8 chunks.  The last chunk will
  -- also be of the specified chunk size filled with trailing zeros.
  asVector8ns :: Int -> a -> [DVS.Vector Word8]

instance AsVector8ns LBS.ByteString where
  asVector8ns n = asVector8ns n . LBS.toChunks
  {-# INLINE asVector8ns #-}

instance AsVector8ns [BS.ByteString] where
  asVector8ns = bytestringsToVectors
  {-# INLINE asVector8ns #-}

bytestringsToVectors :: Int -> [BS.ByteString] -> [DVS.Vector Word8]
bytestringsToVectors n = go
  where go :: [BS.ByteString] -> [DVS.Vector Word8]
        go bss = case bss of
          (cs:css) -> let csz = BS.length cs in
            if csz >= n
              then if csz `mod` n == 0
                then asVector8 cs:bytestringsToVectors n css
                else let p = (csz `div` n) * n in
                  asVector8 (BS.take p cs):bytestringsToVectors n (BS.drop p cs:css)
              else if csz > 0
                then case DVS.createT (buildOneVector n bss) of
                  (dss, ws) -> if DVS.length ws > 0
                    then ws:go dss
                    else []
                else bytestringsToVectors n css
          [] -> []
{-# INLINE bytestringsToVectors #-}

buildOneVector :: forall s. Int -> [BS.ByteString] -> ST s ([BS.ByteString], DVS.MVector s Word8)
buildOneVector n ss = case dropWhile ((== 0) . BS.length) ss of
  [] -> ([],) <$> DVSM.new 0
  cs -> do
    v64 <- DVSM.unsafeNew n
    let v8 = DVSM.unsafeCast v64
    rs  <- go cs v8
    return (rs, v64)
  where go :: [BS.ByteString] -> DVSM.MVector s Word8 -> ST s [BS.ByteString]
        go ts v = if DVSM.length v > 0
          then case ts of
            (u:us) -> if BS.length u <= DVSM.length v
              then case DVSM.splitAt (BS.length u) v of
                (va, vb) -> do
                  DVSM.copy va (byteStringToVector8 u)
                  go us vb
              else case BS.splitAt (DVSM.length v) u of
                (ua, ub) -> do
                  DVSM.copy v (byteStringToVector8 ua)
                  return (ub:us)
            [] -> do
              DVSM.set v 0
              return []
          else return ts
        {-# INLINE go #-}
{-# INLINE buildOneVector #-}

byteStringToVector8 :: BS.ByteString -> DVSM.MVector s Word8
byteStringToVector8 bs = case BS.toForeignPtr bs of
  (fptr, off, len) -> DVSM.unsafeFromForeignPtr (castForeignPtr fptr) off len
{-# INLINE byteStringToVector8 #-}
