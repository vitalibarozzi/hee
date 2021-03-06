{-# LANGUAGE ExistentialQuantification #-}

class Moo m where
  f :: a -> m
  g :: m -> Int -> m

instance Moo Char where
  f x = 'c'
  g c _ = c

instance Moo Int where
  f x = 100
  g i _ = i

instance Moo AnyMoo where
  g m _ = m

data AnyMoo
  = forall m. (Show m, Moo m) => AnyMoo m

instance Show AnyMoo where
  show (AnyMoo x) = show x

xs :: [AnyMoo]
xs = [AnyMoo 'a', AnyMoo 'b', AnyMoo (0::Int), AnyMoo (1::Int)]

showX :: [AnyMoo] -> String
showX xs = case head xs of (AnyMoo x) -> show x

-- "My brain just exploded"
--showY :: [AnyMoo] -> String
--showY ys = let (AnyMoo y) = head ys
--           in show y

-- This is ill-typed, because we can't let x "escape"
-- as a value. But we can apply any functions defined
-- on Show (eg, `show x`) or Moo (eg `f x`)
--
--firstX xs = case head xs of (AnyMoo x) -> x

-- Losing type information through AnyMoo
-- g                      :: (Moo m) => m -> Int -> m
--
-- g 'c'                  :: Int -> Char
-- g (AnyMoo 'c')         :: Int -> AnyMoo
--
-- g (0 :: Int)           :: Int -> Int
-- g (AnyMoo (0 :: Int))  :: Int -> AnyMoo

