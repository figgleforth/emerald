require 'pp'

class Expr
	attr_accessor :string, :tokens, :token

	def tokens
		@tokens ||= []
	end

	def to_s
		"#{self.class.name}(#{string})"
	end

	def isa other
		return false if other.nil?
		if other.is_a? Class
			other == self.class || self.is_a?(other)
		else
			other == string
		end
	end

	# def isa other
	# 	return false if other.nil?
	# 	other == self.class || self.is_a?(other)
	# end

	def is other
		return false unless other
		return string == other if other.is_a? String
		other == self.class || self.is_a?(other)
	end
end

class Func_Expr < Expr
	attr_accessor :expressions, :compositions, :parameters, :signature

	def initialize
		@parameters  = []
		@expressions = []
	end

	def signature # todo to support multiple methods with the same name, each method needs to be able to be represented as a signature. Naive idea: name+parameters+
		# @signature ||= "#{name}".tap do |it|
		# 	parameters.each do |param|
		# 		# it: Function_Param_Expr
		# 		# maybe also use compositions in the signature for better control over signature equality
		# 		it << "#{param.label}:#{param.name}=#{param.default}"
		# 	end
		# end
	end

	def to_s
		word = if expressions.count == 1
			'expression'
		else
			'expressions'
		end
		"#{self.class.name}(#{parameters.join(', ')}; #{expressions.map(&:to_s)}"
	end
end

class Func_Decl < Func_Expr
	attr_accessor :name

	def to_s
		word = if expressions.count == 1
			'expression'
		else
			'expressions'
		end
		"#{self.class.name}(#{name.string}{#{parameters.join(', ')}; #{expressions.map(&:to_s)}})"
	end
end

class Operator_Decl < Func_Decl
	attr_accessor :fix # pre, in, post, circumfix

	def to_s
		"#{fix.string} #{name.string} {#{parameters.map(&:name).map(&:string).join(',')};}"
	end
end

class Func_Param_Decl < Expr
	attr_accessor :name, :label, :type, :default, :portal

	def initialize
		super
		@portal  = false
		@default = nil
		@name    = nil
		@label   = nil
		@type    = nil
	end

	def to_s
		str = ''

		str += "#{label.string}: " if label
		str += name.inspect
		str += " = #{default}" if @default

		str
	end
end

# todo rename to Param_Expr
class Call_Arg_Expr < Expr
	attr_accessor :expression, :label

	def to_s
		if label
			"#{label.string}: #{expression}"
		else
			expression.to_s
		end
	end
end

class Class_Decl < Expr
	attr_accessor :name, :expressions, :base_class, :compositions
	# todo) remove base_class because a class can be a collection of types, so `Player > Input, Renderer, Inventory {}` means this class is simultaneously Player, Input, Renderer, and Inventory. That's because by composing, these classes are able to respond to methods that Input, Renderer, etc are normally able to.

	def initialize
		super
		@compositions = []
	end

	def to_s
		"#{name.string}{#{expressions.join(', ')}}"
	end
end

class Number_Expr < Expr
	attr_accessor :type, :decimal_position

	def initialize
		super
	end

	def string= val
		@string = val.gsub('_', '')
		if val[0] == '.'
			@type             = :float
			@decimal_position = :start
		elsif val[-1] == '.'
			@type             = :float
			@decimal_position = :end
		elsif val&.include? '.'
			@type             = :float
			@decimal_position = :middle
		else
			@type = :int
		end
	end

	# def to_s
	# 	"#{self.class.name}(#{string})"
	# end

	# Useful reading
	# https://stackoverflow.com/a/18533211/1426880
	# https://stackoverflow.com/a/1235891/1426880
end

class Symbol_Literal_Expr < Expr
	def to_symbol
		":#{string}"
	end
end

class String_Expr < Expr
	require './lang/helpers/constants'
	attr_accessor :interpolated

	def string= val
		@string       = val
		@interpolated = val.include? COMMENT_CHAR # if at least one ` is present then it should be interpolated, if formatted properly.
	end

	def to_s
		"#{self.class.name}(#{string.inspect})"
	end
end

class Hash_Expr < Expr
	attr_accessor :keys, :values # ??? these two zipped together will for the key/val pairs

	def initialize
		super
		@keys   = []
		@values = []
	end

	def to_s
		zipped = keys.zip(values).map {
			key, val = _1
			"#{key.to_s}: #{val.to_s}"
		}.join(', ')
		"Hash(#{keys.count}){#{zipped}}"
	end
end

class Array_Expr < Expr
	attr_accessor :elements

	def initialize
		super
		@elements = []
	end

	def to_s
		"[#{elements.map(&:to_s).join(',')}]"
	end
end

class Prefix_Expr < Expr
	attr_accessor :operator, :expression

	def to_s
		"(#{operator}#{expression}"
	end
end

class Postfix_Expr < Expr
	attr_accessor :operator, :expression

	def to_s
		"#{expression}:#{operator})"
	end
end

class Infix_Expr < Expr
	attr_accessor :operator, :left, :right

	def initialize
		super
	end

	def to_s
		"#{self.class.name}(#{left.to_s}#{operator.string}#{right.to_s})"
	end
end

class Circumfix_Expr < Expr # one or more comma, or maybe even space-separated, expressions
	# @return [Array] of comma separated expressions that make up this Expr
	attr_accessor :grouping, :expressions

	def initialize(grouping = '(')
		@expressions = []
		@grouping    = grouping
	end

	def empty?
		expressions.empty?
	end

	def to_s
		"Set#{grouping[0]}#{expressions.map(&:to_s).join(', ')}#{grouping[1]}"
	end
end

class Operator_Expr < Expr

	# def == other
	# 	self === other
	# end

	def isa other
		if other.is_a? Class
			other < Operator_Expr && other.token.string == token.string
		elsif other.is_a? String
			string == other
		else
			raise "Operator_Expr#==/=== not sure how to equate with #{other.inspect}"
		end
	end

	def to_s
		"#{string}"
	end
end

class Identifier_Expr < Expr
	def to_s
		token.string
	end

	def inspect
		to_s
	end

	def isa other
		other.is_a?(Identifier_Expr) && other.string == string
	end

end

class Key_Identifier_Expr < Identifier_Expr
end

class Composition_Expr < Expr
	attr_accessor :operator, :expression
end

class Class_Composition_Expr < Composition_Expr
	attr_accessor :alias_identifier

end

class Conditional_Expr < Expr
	attr_accessor :condition, :when_true, :when_false
end

class While_Expr < Expr
	attr_accessor :condition, :when_true, :when_false
end

class Raise_Expr < Expr # expressions that can halt the program. Right now that's oops and >~
	attr_accessor :name, :expression
end

class Nil_Expr < Expr
end

class Return_Expr < Expr
	attr_accessor :expression
end

class Call_Expr < Expr
	attr_accessor :receiver, :arguments

	#
	def to_s
		"#{receiver}(#{arguments.join(', ')})"
	end
end

class Route_Decl < Func_Expr
	# request_method, String_Literal, Identifier_Token, {
	# eg. get '/' home { ; }
	attr_accessor :route, :name
end

class Enum_Decl < Expr
=begin

CONST = some_expression
WEIRD_ALPHABET {
	A
	B {
		C
	}
}

WEIRD_ALPHABET.A
WEIRD_ALPHABET.B
WEIRD_ALPHABET.B.C
WEIRD_ALPHABET.A.D

=end
	attr_accessor :identifier, :expression
end
