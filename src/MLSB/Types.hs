{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveTraversable #-}

module MLSB.Types where

import Text.Show.Deriving (deriveShow1)
import Text.Read.Deriving (deriveRead1)
import Data.Eq.Deriving (deriveEq1)
import Data.Functor.Classes (Show1(..))
import Data.Functor.Foldable (Fix(..), Recursive(..), Corecursive(..))
import Data.Functor.Foldable.TH (makeBaseFunctor)

type Id = String

data Pat = Pat String
  deriving(Eq,Ord,Show,Read)

data Const =
    ConstR Rational
  | ConstS String
  deriving (Eq,Ord,Show,Read)

eqConst :: Rational -> Const -> Const -> Bool
eqConst tol a b =
  case (a,b) of
    (ConstR af,ConstR bf) -> abs (af-bf) < tol
    (ConstS as,ConstS bs) -> as == bs
    _ -> False

-- | Data type representing lambda-calculus expressions.
data Expr =
    Const Const
    -- ^ Constant
  | Ident Id
    -- ^ Bare identifier
  | Lam Pat Expr
    -- ^ A lambda abstraction.
  | Let Pat Expr Expr
    -- ^ Let-binding
  | App Expr Expr
    -- ^ Application
  deriving (Eq,Ord,Show,Read)

makeBaseFunctor ''Expr
deriveShow1 ''ExprF
deriveRead1 ''ExprF
deriveEq1   ''ExprF

type Expr1 = Fix ExprF

{-
eqExpr :: Rational -> Expr -> Expr -> Bool
eqExpr tol ea eb =
  let
    go a b = eqExpr tol a b
  in
  case (ea, eb) of
    (Const ca,Const cb) -> eqConst tol ca cb
    (Ident a,Ident b) -> a==b
    (Lam p1 e1,Lam p2 e2) -> p1==p2 && (go e1 e2)
    (Let p1 ea1 eb1,Let p2 ea2 eb2) -> p1==p2 && (go ea1 ea2) && (go eb1 eb2)
    (App ea1 ea2,App eb1 eb2) -> (go ea1 ea2) && (go eb1 eb2)
    _ -> False
-}

data Program = Program Expr
  deriving (Show,Read)

