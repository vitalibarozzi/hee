package com.github.kputnam.bee
package types

object VariableLike {
  val lowerGreek = "αβγδεζηθικλμνξοπρςστυ φχψω".replace(" ", "")
  val upperGreek = "ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡ ΣΤΥ ΦΧΨΩ".replace(" ", "")
  val lowerLatin = "abcdefghijklmnopqrstuvwxyz"
  val upperLatin = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

  def toInt(c: Char): Int =
    (-1 /: List(lowerGreek, upperGreek, lowerLatin, upperLatin)) ((k, alphabet) =>
      if (k < 0) alphabet.indexOf(c) else k)

  def toInt(s: String): Int = {
    def index(s: String, alphabet: String) =
      if (alphabet.indexOf(s(0)) < 0) -1
      else alphabet.indexOf(s(0)) + alphabet.length * (s.length - 1)

    (-1 /: List(lowerGreek, upperGreek, lowerLatin, upperLatin)) ((k, alphabet) =>
      if (k < 0) index(s, alphabet) else k)
  }
}

trait VariableLike { self: Type =>
  protected def alphabet: String

  def id: Int
  def skolemize: Type

  override def isMonomorphic = false
  override def isPolymorphic = true
  override def hasOccurrence(x: VariableLike) =
    this.id == x.id

  def freeVariables: Set[VariableLike] =
    Set(this)

  def occursIn(τ: Type) =
    τ.hasOccurrence(this)

  override def toString = {
    val remainder = id % alphabet.length
    val dividend  = id / alphabet.length
    alphabet(remainder) + ("'" * dividend)
  }

  override def equals(that: Any) = that match {
    case that: VariableLike => that.id == this.id
    case _ => false
  }

}
