{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE TemplateHaskellQuotes #-}

-- |
-- Module      : Data.Boltzmann.Specification
-- Description :
-- Copyright   : (c) Maciej Bendkowski, 2022
-- License     : BSD3
-- Maintainer  : maciej.bendkowski@gmail.com
-- Stability   : experimental
module Data.Boltzmann.Specification
  ( TypeSpec,
    SystemSpec (..),
    samplableType,
    weight,
    frequency,
    defaultTypeSpec,
    withWeights,
    withFrequencies,
    specification,
    withSystem,
    (==>),
    collectTypes,
    ConsFreq,
    constructorFrequencies,
    getWeight,
    getFrequency,
  )
where

import Data.Bifunctor (Bifunctor (first))
import Data.Boltzmann.Specifiable
  ( Cons (args),
    Specifiable (..),
    SpecifiableType (..),
  )
import qualified Data.Map as Map
import Data.Map.Strict (Map)
import Data.Maybe (fromJust)
import Data.Set (Set)
import qualified Data.Set as Set
import Language.Haskell.TH.Syntax (Name)

data TypeSpec = forall a.
  Specifiable a =>
  TypeSpec
  { samplableType :: a,
    weight :: Map String Integer,
    frequency :: Map String Integer
  }

instance Eq TypeSpec where
  TypeSpec {samplableType = typ} == TypeSpec {samplableType = typ'} =
    typeName typ == typeName typ'

instance Ord TypeSpec where
  TypeSpec {samplableType = typ} <= TypeSpec {samplableType = typ'} =
    typeName typ <= typeName typ'

data SystemSpec = forall a.
  Specifiable a =>
  SystemSpec {targetType :: a, meanSize :: Integer, typeSpecs :: Set TypeSpec}

getWeight :: SystemSpec -> String -> Integer
getWeight sys name =
  if Set.size res == 0
    then 1 -- default weight
    else fromJust (head $ Set.toList res)
  where
    res = Nothing `Set.delete` Set.map (getWeight' name) (typeSpecs sys)

getWeight' :: String -> TypeSpec -> Maybe Integer
getWeight' name spec = name `Map.lookup` weight spec

getFrequency :: SystemSpec -> String -> Maybe Integer
getFrequency sys name =
  if Set.size res == 0
    then Nothing -- default frequency
    else head $ Set.toList res
  where
    res = Nothing `Set.delete` Set.map (getFrequency' name) (typeSpecs sys)

getFrequency' :: String -> TypeSpec -> Maybe Integer
getFrequency' name spec = name `Map.lookup` frequency spec

defaultTypeSpec :: Specifiable a => a -> TypeSpec
defaultTypeSpec typ =
  TypeSpec
    { samplableType = typ,
      weight =
        Map.fromList
          [ (show '[], 0),
            (show '(:), 0)
          ],
      frequency = Map.empty
    }

type Value = (Name, Integer)

(==>) :: Name -> Integer -> Value
consName ==> w = (consName, w)

infix 6 ==>

withWeights :: [Value] -> TypeSpec -> TypeSpec
withWeights values spec = spec {weight = weight spec `Map.union` valMap}
  where
    valMap = Map.fromList $ map (first show) values

withFrequencies :: [Value] -> TypeSpec -> TypeSpec
withFrequencies values spec =
  spec {frequency = frequency spec `Map.union` valMap}
  where
    valMap = Map.fromList $ map (first show) values

specification :: Specifiable a => a -> (TypeSpec -> TypeSpec) -> TypeSpec
specification typ f = f (defaultTypeSpec typ)

withSystem :: Specifiable a => (a, Integer) -> [TypeSpec] -> SystemSpec
withSystem (typ, size) specs =
  SystemSpec
    { targetType = typ,
      meanSize = size,
      typeSpecs = Set.fromList specs
    }

toSpecifiableTypes :: SystemSpec -> Set SpecifiableType
toSpecifiableTypes = Set.map toSpecifiableType . typeSpecs

toSpecifiableType :: TypeSpec -> SpecifiableType
toSpecifiableType (TypeSpec {samplableType = t}) = SpecifiableType t

collectTypes :: SystemSpec -> Set SpecifiableType
collectTypes sys =
  foldl collectTypesFromSpecifiableType Set.empty (toSpecifiableTypes sys)

collectTypesFromSpecifiableType ::
  Set SpecifiableType -> SpecifiableType -> Set SpecifiableType
collectTypesFromSpecifiableType types st@(SpecifiableType typ)
  | st `Set.member` types = types
  | otherwise = foldl collectTypesFromCons types' (typedef typ)
  where
    types' = st `Set.insert` types

collectTypesFromCons :: Set SpecifiableType -> Cons -> Set SpecifiableType
collectTypesFromCons types cons =
  foldl collectTypesFromSpecifiableType types (args cons)

type ConsFreq = Map String Integer

constructorFrequencies :: SystemSpec -> ConsFreq
constructorFrequencies sys = Map.unions consFreqs
  where
    typeSpecs' = Set.toList (typeSpecs sys)
    consFreqs = map constructorFrequencies' typeSpecs'

constructorFrequencies' :: TypeSpec -> ConsFreq
constructorFrequencies' (TypeSpec {frequency = freq}) = freq
