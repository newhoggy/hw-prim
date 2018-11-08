{-# OPTIONS_GHC -fno-warn-incomplete-patterns #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

module HaskellWorks.Data.Vector.StorableSpec
  ( spec
  ) where

import HaskellWorks.Hspec.Hedgehog
import Hedgehog
import Test.Hspec

import qualified Data.List                         as L
import qualified Data.Vector.Storable              as DVS
import qualified HaskellWorks.Data.Vector.Storable as DVS
import qualified Hedgehog.Gen                      as G
import qualified Hedgehog.Range                    as R

{-# ANN module ("HLint: Ignore Redundant do" :: String) #-}

spec :: Spec
spec = describe "HaskellWorks.Data.Vector.StorableSpec" $ do
  it "mapAccumL: f a b = (a + 1, b * 2)" $ requireProperty $ do
    as <- forAll $ G.list (R.linear 0 10) (G.word64 (R.linear 0 255))
    let f a b = (a + 1, b * 2)
    (DVS.toList <$> DVS.mapAccumL f (0 :: Int) (DVS.fromList as)) === L.mapAccumL f (0 :: Int) as
  it "mapAccumL: f a b = (a * 2, b + 1)" $ requireProperty $ do
    as <- forAll $ G.list (R.linear 0 10) (G.word64 (R.linear 0 255))
    let f a b = (a * 2, b + 1)
    (DVS.toList <$> DVS.mapAccumL f (0 :: Int) (DVS.fromList as)) === L.mapAccumL f (0 :: Int) as
