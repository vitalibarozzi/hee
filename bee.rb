require "strscan"
require "term/ansicolor"

class String
  include Term::ANSIColor

  # Dumb way to distinguish bee chars (modeled with ::String) from
  # bee strings (represented with Bee::String or Bee::Cons), eg 'x'
  # instead of "x"
  alias _inspect inspect
  def inspect
    "'#{_inspect[1..-2]}'"
  end
end

module Bee

  class Term
    def name?
      false
    end

    def literal?
      false
    end

    def quotation?
      false
    end
  end

  class Name < Term
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def name?
      true
    end

    def inspect
      @name
    end

    def unparse
      @name
    end
  end

  class Literal < Term
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def literal?
      true
    end

    def inspect
      @value.inspect
    end

    def unparse
      @value.inspect
    end
  end

  class List
    # Prepend an element
    def cons(head)
      Cons.new(head, self)
    end

    # Lower a bee string to Ruby's String
    def to_s
      lst = self
      str = ""

      until lst.null?
        str << lst.head.to_s
        lst  = lst.tail
      end

      str
    end
  end

  Null = Class.new(List) do
    def null?
      true
    end

    def head
      raise "head of empty list"
    end

    def tail
      self
    end

    def inspect
      "null"
    end
  end.new

  class Cons < List
    attr_reader :head, :tail

    def initialize(head, tail)
      @head, @tail = head, tail
    end

    def null?
      false
    end

    # Show lists of bee chars (modeled by ::String) as "strings" but
    # format non-char lists as (a b c ...)
    def inspect
      fmt = "("
      str = '"'
      lst = self

      unless lst.null?
        until lst.null?
          str &&= (::String === lst.head) && (str << lst.head)
          fmt  << lst.head.inspect
          fmt  << " "
          lst   = lst.tail
        end

        str ?
          str.gsub("\n", "\\n").gsub("\r", "\\r").gsub("\t", "\\t") << '"' :
          fmt[0..-2]  << ")"
      else
        "null"
      end
    end
  end

  class String < Literal
    def initialize(value)
      @value = value.chars.to_a
    end

    # Not used, evaluated with #value first
    def head
      if @value.empty?
        raise "head of empty list"
      else
        @value[0]
      end
    end

    # Not used, evaluated with #value first
    def tail
      (@value[1..-1] || []).reverse.inject(Null){|tail,head| Cons.new(head, tail) }
    end

    # Not used, evaluated with #value first
    def cons(head)
      Cons.new(head, self)
    end

    def value
      @value.reverse.inject(Null){|tail,head| Cons.new(head, tail) }
    end

    def inspect
      @value.join.inspect
    end

    def unparse
      @value.join.inspect
    end

    def to_s
      @value.join
    end
  end

  class Quotation < Term
    attr_reader :terms

    def initialize(terms = [])
      @terms = terms
    end

    def append(term, *terms)
      @terms.push(term, *terms)
      self
    end

    def quotation?
      true
    end

    def inspect
      "[" + @terms.map(&:inspect).join(" ") + "]"
    end

    def unparse
      "[" + @terms.map(&:unparse).join(" ") + "]"
    end
  end

  class Definition
    attr_reader :name, :terms

    def initialize(name = nil, terms = [])
      @name  = name
      @terms = terms
    end

    def append(token, *tokens)
      if @name.nil?
        @name = token.name
      else
        @terms.push(token, *tokens)
      end
    end
  end

  class Dictionary
    attr_reader :storage

    def initialize
      @storage = {}
    end

    def add(definition)
      @storage[definition.name] = definition.terms
      self
    end

    def defined?(name)
      @storage.include?(name)
    end

    # @return [Term]
    def lookup(name)
      @storage[name] or raise "undefined `#{name}'"
    end

    def import(other)
      @storage.merge!(other.storage)
      self
    end

    def definitions
      @storage.map{|name, terms| Definition.new(name, terms) }
    end
  end

  class Parser

    # @return [[Terms], Dictionary]
    def parse(unparsed)
      dictionary = Dictionary.new
      nesting = [Quotation.new]
      scanner = StringScanner.new(unparsed)
      scanner.skip(/\s+/)

      while token = scanner.scan(/\[|\]|"[^"]*"|'[^']*'|[^\s\]]+/)
        case token
        when "["
          Quotation.new.tap do |q|
            nesting.last.append(q)
            nesting.push(q)
          end
        when "]"
          raise "unexpected ]" unless nesting.size > 1
          nesting.pop
        when ":"
          nesting.push(Definition.new)
        when ";"
          dictionary.add(nesting.pop)
        else
          nesting.last.append(*term(token))
        end

        scanner.skip(/\s+/)
      end

      raise "unexpected EOF" unless nesting.size == 1
      return nesting.first.terms, dictionary
    end

    def term(token)
      case token
      when /^-?\d+$/;       Literal.new(token.to_i)
      when /^-?\d*\.\d+$/;  Literal.new(token.to_f)
      when /^'([^']{1})'$/; Literal.new(token[1..1])
      when /^'\\n'$/;       Literal.new("\n")
      when /^'\\r'$/;       Literal.new("\r")
      when /^'\\t'$/;       Literal.new("\t")
      when /^'\\\\'$/;      Literal.new("\\")
      when /^"([^"]*)"$/;   String.new(token[1..-2].gsub("\\t", "\t").gsub("\\n", "\n").gsub("\\r", "\r"))
      when /^'([^']*)'$/;   String.new(token[1..-2].gsub("\\t", "\t").gsub("\\n", "\n").gsub("\\r", "\r"))
      when "true";          Literal.new(true)
      when "false";         Literal.new(false)
      else                  Name.new(token)
      end
    end

    def unparse(o)
      case o
      when Definition
        ": #{o.name}\n  #{o.terms.map{|p| unparse(p) }.join(' ')} ;\n\n"
      when Quotation
        o.unparse
      when Literal
        o.unparse
      when Name
        o.unparse
      else
        raise "can't unparse #{o.class}"
      end
    end
  end

  class Interpreter
    attr_reader :stack, :input, :dictionary

    def initialize(debug = true)
      @debug = debug
      @stack = []
      @input = []
      @dictionary = Dictionary.new
    end

    def run(debug, terms, dictionary)
      @dictionary.import(dictionary)
      @input.concat(terms)

      # Store triples of stack + current + continuation
      trace = []

      until (term = @input.shift).nil?
        trace << [@stack.map(&:inspect).join(" "), term.inspect, @input.map(&:inspect).join(" ")] if debug

        if !term.is_a?(Term)
          @stack.push(term)
        elsif term.literal?
          @stack.push(term.value)
        elsif term.quotation?
          @stack.push(term)
        elsif term.name?
          case term.name
          when "id", "nop" # S -> S

          when "halt" # S -> 0
            @stack = []
            @input = []

          when "print" # S t -> S
            a = @stack.pop
            $stdout.puts(a.inspect)

          when "apply" # S (S -> T) -> T
            a = @stack.pop
            @input.unshift(*a.terms)

          when "quote" # S t -> S (U -> U t)
            a = @stack.pop
            @stack.push(Quotation.new([a]))

          when "compose" # S (X -> Y) (Y -> Z) -> S (X -> Z)
            b = @stack.pop
            a = @stack.pop
            @stack.push(Quotation.new(a.terms + b.terms))

          when "pop" # S t -> S
            @stack.pop

          when "swap" # S t u -> S u t
            b = @stack.pop
            a = @stack.pop
            @stack.push(b)
            @stack.push(a)

          when "dup" # S t -> S t t
            a = @stack.pop
            @stack.push(a)
            @stack.push(a)

          when "dip" # S (S -> T) u -> T u
            b = @stack.pop
            a = @stack.pop
            @input.unshift(a)
            @input.unshift(*b.terms)

          when "dig" # S a b c -> S b c a
            c = @stack.pop
            b = @stack.pop
            a = @stack.pop
            @stack.push(b)
            @stack.push(c)
            @stack.push(a)

          when "if" # S boolean t t -> S t
            c = @stack.pop
            b = @stack.pop
            a = @stack.pop
            @stack.push(a ? b : c)

          when "="
            b = @stack.pop
            a = @stack.pop
            @stack.push(a == b)

          when *%w(+ - * / % ** < <= == >= > >> << & | ^)
            b = @stack.pop
            a = @stack.pop
            @stack.push(a.__send__(term.name.to_sym, b))

          when "/%"
            b = @stack.pop
            a = @stack.pop
            @stack.push(a / b)
            @stack.push(a % b)

          when "%/"
            b = @stack.pop
            a = @stack.pop
            @stack.push(a % b)
            @stack.push(a / b)

          when "to_s"
            a = @stack.pop
            @stack.push(a.to_s.reverse.chars.inject(Null){|tail,head| Cons.new(head,tail) })

          when *%w(to_i to_f)
            a = @stack.pop
            @stack.push(a.to_s.__send__(term.name.to_sym))

          when "and" # S boolean boolean -> S boolean
            b = @stack.pop
            a = @stack.pop
            @stack.push(a && b)

          when "or" # S boolean boolean -> S boolean
            b = @stack.pop
            a = @stack.pop
            @stack.push(a || b)

          when "xor" # S boolean boolean -> S boolean
            b = @stack.pop
            a = @stack.pop
            @stack.push(a ^ b)

          when "not" # S boolean -> S boolean
            a = @stack.pop
            @stack.push(!a)

          when "null" # S -> S list
            @stack.push(Null)

          when "cons" # S list t -> S t-list
            b = @stack.pop
            a = @stack.pop
            @stack.push(a.cons(b))

          # Should this be polymorphic?
          #   boolean [true-case] [false-case] fold
          #   option  [some-case] [none-case]  fold
          #   either  [left-case] [right-case] fold
          #   list    [null-case] [cons-case]  fold
          #
          # Probably not, because the number of cases (arguments) depends on
          # the data type definition. Type classes can't safely handle per-
          # instance arity -- needs research -- and readability would suffer
          # as reading "fold" in the source could imply several meanings
          when "unlist" # S t-list (S -> U) (S t-list t -> U) -> U
            c = @stack.pop
            b = @stack.pop
            a = @stack.pop
            if a.null?
              @input.unshift(*b.terms)
            else
              @stack.push(a.tail)
              @stack.push(a.head)
              @input.unshift(*c.terms)
            end

          when "dump-defs" # S string -> S
            a = @stack.pop
            p = Parser.new

            File.open(a.to_s, "w+") do |io|
              @dictionary.definitions.each{|d| io << p.unparse(d) }
            end

          when "load-defs" # S string -> S
            a    = @stack.pop
            t, d = Parser.new.parse(File.read(a.to_s))
            @dictionary.import(d)

          when "expand-def" # S (T -> U) -> S (T -> U)
            a = @stack.pop
            q = Quotation.new

            while t = a.terms.shift
              if t.name? and @dictionary.defined?(t.name)
                q.terms.push(*@dictionary.lookup(t.name))
              else
                q.terms.push(t)
              end
            end

            @stack.push(q)

          else
            @input.unshift(*@dictionary.lookup(term.name))
          end
        end
      end

      @stack
    ensure
      unless trace.empty?
        s = trace.map{|_| _[0].length }.max # stack
        t = trace.map{|_| _[1].length }.max # eval term
        c = trace.map{|_| _[2].length }.max # continuation

        maxs, maxt, maxc = trace.inject([0,0,0]) do |(s,t,c), _|
          [ s > _[0].length ? s : _[0].length,
            t > _[1].length ? t : _[1].length,
            c > _[2].length ? c : _[2].length ]
        end

        trace.each do |t|
          $stdout.puts ".. " << t[0].rjust(maxs).yellow <<
                       " : " << t[1].rjust(maxt).cyan   <<
                     ((" : " << t[2])[maxs+maxt .. 80] || "")
        end
      end
    end

  end
end

###############################################################################

$vm = Bee::Interpreter.new
$p  = Bee::Parser.new

if File.exists?("runtime.bee")
  $vm.run(false, *$p.parse(File.read("runtime.bee")))
else
  $stderr.puts "cannot load runtime.bee from current directory".yellow
end

#$vm.dictionary.add(Bee::Definition.new("map",
#  $p.parse("swap [pop null] [dig dup dip [swap] dip map swap cons] unlist").first))

#$vm.dictionary.add(Bee::Definition.new("length",
#  $p.parse("[0] [pop length 1 +] unlist").first))

#$vm.dictionary.add(Bee::Definition.new("sum",
#  $p.parse("[0] [swap sum +] unlist").first))

def bee(unparsed, debug = false)
  $vm.run(debug, *$p.parse(unparsed))
rescue
  $vm.input.clear
  $stderr.puts $!.to_s.red
# $stderr.puts "  " << $!.backtrace.join("\n  ")
end

def time(n, &block)
  a = Time.now
  c = nil
  n.times do |m|
    b = Time.now
    print "#{m}... "
    block.call
    c = Time.now
    puts c - b
  end
  return (c - a)/n
end

################################################################################
#
# $ irb -rbee
# >> bee "5 2 -"
# => [3]
#
# >> bee "'runtime.bee' load-defs"
# => []
#
# >> bee "3 bottles"
# 3 bottles
# 2 bottles
# 1 bottles
# 0 bottles
# => []
#
# >> bee "3 4 5 [+] twice"
# => [12]
#
# >> bee "'bebe' length"
# => [12, 4]
#
# >> bee "pop pop"
# => []
#
# >> bee ": xs null 3 cons 2 cons 1 cons ;"
# => [[1,2,3]]
#
# >> bee "xs sum"
# => [6]
#
# >> "xs [dup *] map"
# => [6, [1,4,9]]
#
################################################################################
