{-# LANGUAGE TemplateHaskell #-}

module Tree (Tree (..), randomTreeListIO) where

import Control.Monad (replicateM)

import Data.Boltzmann (
  BoltzmannSampler (..),
  evalIO,
  mkDefBoltzmannSampler,
  toleranceRejectionSampler,
 )

import System.Random.SplitMix (SMGen)

data Tree = T [Tree]
  deriving (Show)

mkDefBoltzmannSampler ''Tree 100

randomTreeListIO :: Int -> IO [Tree]
randomTreeListIO n =
  evalIO $ replicateM n (toleranceRejectionSampler @SMGen 1000 0.2)

newtype Tree' = MkTree' Tree
  deriving (Show)

mkDefBoltzmannSampler ''Tree' 2000
