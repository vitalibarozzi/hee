module Hee.Checker
  where

import Hee.Terms
import Hee.Types
import Hee.Substitution
import Hee.Unification
import Hee.Either

checkTerm :: Term -> Either String Type

checkTerm (TmEmpty) =
  let s = StBottom 0
   in return $ s `mkFunc` s

checkTerm (TmName id) =
  lookupName id

checkTerm (TmCompose a b) =
  -- Hmm, assume _ is tFunc
  do (TyApplication (TyApplication _ (TyStack ai)) (TyStack ao)) <- checkTerm a
     (TyApplication (TyApplication _ (TyStack bi)) (TyStack bo)) <- checkTerm b
     s <- unify ao bi
     return $ substitute s (ai `mkFunc` bo)

checkTerm (TmQuote a) =
  let s = StBottom 0
   in do f <- checkTerm a
         return $ s `mkFunc` (StPush s f)

checkTerm (TmLiteral a) =
  let s  = StBottom 0
      a' = checkLit a
   in return $ s `mkFunc` (StPush s a')

lookupName :: String -> Either String Type

lookupName "id" =
  let s = StBottom 0
   in return $ s `mkFunc` s

-- S a -> S
lookupName "pop" =
  let a = mkVar 0
      s = StBottom 0
   in return $ (StPush s a) `mkFunc` s

-- S a -> S a a
lookupName "dup" =
  let a = mkVar 0
      s = StBottom 0
   in return $ (StPush s a) `mkFunc` (StPush (StPush s a) a)

-- S u (S -> T) -> T u
lookupName "dip" =
  let u = mkVar 0
      s = StBottom 0
      t = StBottom 1
      f = s `mkFunc` t
   in return $ (StPush (StPush s u) f) `mkFunc` (StPush t u)

-- S a b -> S b a
lookupName "swap" =
  let s = StBottom 0
      a = mkVar 0
      b = mkVar 1
   in return $ (StPush (StPush s a) b) `mkFunc` (StPush (StPush s b) a)

-- S a -> S (T -> T a)
lookupName "quote" =
  let s = StBottom 0
      t = StBottom 1
      a = mkVar 0
      f = t `mkFunc` (StPush t a)
   in return $ (StPush s a) `mkFunc` (StPush s f)

-- S (S -> T) -> T
lookupName "apply" =
  let s = StBottom 0
      t = StBottom 1
      f = s `mkFunc` t
   in return $ (StPush s f) `mkFunc` t

-- S (T -> U) (U -> V) -> S (T -> V)
lookupName "compose" =
  let s  = StBottom 0
      t  = StBottom 1
      u  = StBottom 2
      v  = StBottom 3
      f  = t `mkFunc` u
      g  = u `mkFunc` v
      fg = t `mkFunc` v
   in return $ (StPush (StPush s f) g) `mkFunc` (StPush s fg)

lookupName x =
  fail $ "unbound identifier: '" ++ x ++ "'"

checkLit :: Literal -> Type
checkLit (LiInt _)    = tInt
checkLit (LiRatn _)   = tRatn
checkLit (LiChar _)   = tChar
checkLit (LiString _) = tString