module Language.Hee.Syntax
  ( Expression(..)
  , Declaration(..)
  , Radix(..)
  , Literal(..)
  , Kind(..)
  , Stack(..)
  , Id
  , Type(..)
  , Bound(..)
  , Variable(..)
  , Kinded(..)
  ) where

import Data.Text

data Declaration
  = DNameBind Text (Maybe Text) (Maybe Text) Expression -- bind an expression to a name
  deriving (Eq, Show)

data Expression
  = EEmpty
  | EName Text
  | EQuote Expression
  | ELiteral Literal
  | ECompose Expression Expression
  | EAnnotate Expression Type
  | EComment Text
  deriving (Eq, Show)

data Radix
  = Binary
  | Octal
  | Decimal
  | Hexadecimal
  deriving (Eq, Show)

data Literal
  = LChar Char
  | LString Text
  | LInteger Radix Int
  | LFloat Float
  | LBool Bool
  deriving (Eq, Show)

data Kind
  = KStack                  -- kind of a stack
  | KType                   -- kind of a base type
  | KConstructor Kind Kind  -- kind of a type constructor
  deriving (Eq, Show)

type Id
  = Int

data Variable
  = Variable Id Kind
  deriving (Eq, Show)

data Stack
  = SEmpty
  | STail Id
  | SPush Type Stack
  deriving (Eq, Show)

data Type
  = TStack Stack
  | TConstructor Text Kind
  | TApplication Type Type
  | TForall Variable Bound Type
  | TQualified [Predicate] Type
  | TVariable Variable
  deriving (Eq, Show)

-- List of identity functions:
--   ∀(β≽∀α.α→α).[β] ⊑ [∀α.α→α]
--   ∀(β≽∀α.α→α).[β] ⊑ ∀α.[α→α]
--
-- (⊑) ⊆ (⊧) ⊆ (≡)
--   ≡, equivalence relation
--   ⊧, abstraction relation
--   ⊑, instance relation

data Bound
  = Rigid     -- ∀(α=υ).τ means τ where α is as polymorphic as υ
  | Flexible  -- ∀(α≽υ).τ means τ where α is equal to or is an instance of υ
  | Bottom    -- ∀α.τ     means τ where α is equal to or is an instance of ⊥
  deriving (Eq, Show)

data Predicate
  = MemberOf Type
  deriving (Eq, Show)

class Kinded a where
  kind :: a -> Kind

instance Kinded Kind where
  kind = id

instance Kinded Type where
  kind (TConstructor _ k) = k
  kind (TVariable x)      = kind x
  kind (TForall _ _ t)    = kind t
  kind (TQualified _ t)   = kind t
  kind (TStack _)         = KStack
  kind (TApplication f _) = let (KConstructor _ k) = kind f in k

instance Kinded Stack where
  kind = const KStack

instance Kinded Variable where
  kind (Variable _ k) = k
