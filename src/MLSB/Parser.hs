{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE RecursiveDo #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE LambdaCase #-}

module MLSB.Parser where

import qualified Data.HashSet as HashSet

import Control.Applicative((<$>),(<*>),(*>),(<*),(<|>),pure,many,some)
import Control.Arrow
import Data.Char
import Data.Foldable(foldr1)
import Data.Functor.Foldable (Fix(..), Recursive(..), Corecursive(..))
import Data.List
import Data.Monoid((<>))
import Text.Earley
import Text.Earley.Mixfix
import Data.HashSet(HashSet)

import MLSB.Types

data ParserError = ParserError String
  deriving(Show, Eq, Ord)

holey :: String -> Holey String
holey ""       = []
holey ('_':xs) = Nothing : holey xs
holey xs       = Just i : holey rest
  where (i, rest) = span (/= '_') xs

builtin_ids,builtin_ops,whitespace,special :: HashSet Char
builtin_ids = HashSet.fromList $ ['a'..'z']<>['A'..'Z']<>['0'..'9']<>"_"
builtin_ops = HashSet.fromList $ "*/+-<>="
whitespace = HashSet.fromList  $ " \t\n"
special = HashSet.fromList     $ ";()."

tokenize :: String -> [String]
tokenize ""        = []
tokenize (x:xs)
  | x `HashSet.member` whitespace = tokenize xs
  | x `HashSet.member` special = [x] : tokenize xs
  | x `HashSet.member` builtin_ids = (x:id_head) : tokenize id_tail
  | x `HashSet.member` builtin_ops = (x:op_head) : tokenize op_tail
  | otherwise = error $ "tokenize: Invalid token: " <> (x:xs)
  where
    (id_head, id_tail) = break (not . flip HashSet.member builtin_ids) xs
    (op_head, op_tail) = break (not . flip HashSet.member builtin_ops) xs

isIdent :: String -> Bool
isIdent = \case
  (x:xs) -> isAlpha x && all isAlphaNum xs
  [] -> False

expr :: forall r . Grammar r (Prod r String String Expr1)
expr =

  let

    table = {- sic! -}
      map (map $ first $ map $ fmap namedToken) $
        (map . map) (first holey) [
          [("_+_", LeftAssoc)]
        , [("_-_", LeftAssoc)]
        , [("_*_", LeftAssoc)]
        , [("_/_", LeftAssoc)]
        ]

    {- Convert matching operators into applications -}
    mixfix_combine [Nothing, Just oper, Nothing] exprs = foldl1 (\a b -> Fix $ AppF a b) ((Fix $ IdentF oper):exprs)
    mixfix_combine h _ = error $ "mixfix_combine: not-implemented for " <> show h

  in mdo

  xexpr1 <-
    rule $ namedToken "(" *> xexpr <* namedToken ")"
           <|> xident <|> xconst <?> "Expr1"
  xexpr <-
    rule $ namedToken "(" *> xexpr <* namedToken ")"
           <|> xapp <|> xident <|> xconst <|> xlet <|> xlam <|> xmix <?> "Expr"
  xconst <- rule $ Fix <$> (ConstF <$> xrational)
  xrational <- rule $ ConstR <$> ((fromInteger . read) <$> satisfy (all isDigit)) <?> "Rational" -- FIXME: accept non-int
  xpat <- rule $ Pat <$> (satisfy isIdent) <?> "Pattern"
  xident <- rule $ Fix <$> (IdentF <$> (satisfy isIdent) <?> "Ident")
  xlam <- rule $ Fix <$> (LamF <$> xpat <*> (namedToken "." *> xexpr) <?> "Lambda")
  xasgn <- rule $ (,) <$> xpat <* namedToken "=" <*> xexpr <* namedToken ";" <?> "Assign"
  xlet <- rule $ flip (foldr (\(p,e) acc -> Fix $ LetF p e acc))
                  <$> (namedToken "let" *> some xasgn) <*> (namedToken "in" *> xexpr) <?> "Let"
  xapp <- rule $ Fix <$> (AppF <$> xexpr <*> xexpr <?> "App")
  xmix <- mixfixExpression table xexpr1 mixfix_combine

  return xexpr


parseExpr1 :: String -> Either ParserError Expr1
parseExpr1 str =
  let
    (res,Report{..}) = fullParses (parser expr) $ tokenize str

    err = "Pos: " <> show position
       <> ": unconsumed: " <> show unconsumed
       <> ": expected one of: " <> (intercalate ", " expected)
  in
  case nub res of
    []  -> Left $ ParserError err
    [Fix e] -> Right (Fix e)
    xs  -> Left $ ParserError $ show position <> ": multiple outputs: [\n" <>
      unlines (flip map xs (\x -> show x <> ",")) <> "]"


parseExpr :: String -> Either ParserError Expr
parseExpr = either Left (Right . cata embed) . parseExpr1

