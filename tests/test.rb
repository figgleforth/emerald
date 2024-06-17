require_relative '../source/lexer/lexer'
require_relative '../source/parser/parser'
require_relative '../source/parser/ast'

puts "\nRunning tests:\n\n"

@tests_ran = 1


def t code, &block
    raise ArgumentError, 'x requires a code string' unless code.is_a?(String)
    raise ArgumentError, 'x requires a block' unless block_given?


    def assert condition = false, message = 'ASSERT FAILED'
        raise message unless condition
    end


    tokens = Lexer.new(code).lex
    ast    = Parser.new(tokens).to_ast

    puts "#{@tests_ran.to_s.rjust(2)}) #{code}"
    block_result  = block.call ast
    parser_output = [ast].flatten.map { |a| a.inspect }

    assert block_result, "\n\nFAILED TEST\n———————————\n#{code}\n———————————\n#{parser_output}"
    @tests_ran += 1
end


t '42' do |it|
    it.is_a? Number_Literal_Expr and
        it.string == '42' and
        it.type == :int and
        it.decimal_position == nil
end

t '42.0' do |it|
    it.is_a? Number_Literal_Expr and
        it.string == '42.0' and
        it.type == :float and
        it.decimal_position == :middle
end

t '42.' do |it|
    it.is_a? Number_Literal_Expr and
        it.string == '42.' and
        it.type == :float and
        it.decimal_position == :end
end

t '.42' do |it|
    it.is_a? Number_Literal_Expr and
        it.string == '.42' and
        it.type == :float and
        it.decimal_position == :start
end

t '"double"' do |it|
    it.is_a? String_Literal_Expr
end

t "'single'" do |it|
    it.is_a? String_Literal_Expr
end

t '"`interpolated`"' do |it|
    it.is_a? String_Literal_Expr and it.interpolated
end

t '[]' do |it|
    it.is_a? Array_Literal_Expr and it.elements.empty?
end

t '[[]]' do |it|
    it.is_a? Array_Literal_Expr and it.elements.one? and
        it.elements[0].is_a? Array_Literal_Expr
end

t '[1, 2, 3]' do |it|
    it.is_a? Array_Literal_Expr and it.elements.count == 3 and
        it.elements.all? { |e| e.is_a?(Number_Literal_Expr) }
end

t '[a, b + c]' do |it|
    it.is_a? Array_Literal_Expr and it.elements.count == 2 and
        it.elements[0].is_a? Identifier_Expr and
        it.elements[1].is_a? Binary_Expr
end

t 'x' do |it|
    it.is_a? Identifier_Expr
end

t 'x =;' do |it|
    it.is_a? Assignment_Expr
end

t 'x = 0' do |it|
    it.is_a? Assignment_Expr and
        it.expression.is_a? Number_Literal_Expr and
        it.expression.string == '0'
end

t 'x = ENUM.VALUE' do |it|
    it.is_a? Assignment_Expr and
        it.expression.is_a? Binary_Expr and
        it.expression.left.is_a? Identifier_Expr and
        it.expression.right.is_a? Identifier_Expr
end

t '{}' do |it|
    it.is_a? Function_Expr and
        it.expressions.empty? and
        it.compositions.empty? and
        it.parameters.empty?
end

t 'x = {}' do |it|
    it.is_a? Assignment_Expr and
        it.expression.is_a? Function_Expr and
        it.expression.expressions.empty? and
        it.expression.compositions.empty? and
        it.expression.parameters.empty?
end

t 'x = Abc {}' do |it|
    it.is_a? Assignment_Expr and
        it.expression.is_a? Class_Expr and
        it.expression.block.expressions.empty? and
        it.expression.block.compositions.empty? and
        it.expression.compositions.empty?
end

t 'x {}' do |it|
    it.is_a? Function_Expr and
        it.expressions.empty? and
        it.compositions.empty? and
        it.parameters.empty?
end

t 'x { 42 }' do |it|
    it.is_a? Function_Expr and
        it.expressions.one? and
        it.expressions.first.is_a? Number_Literal_Expr and
        it.compositions.empty? and
        it.parameters.empty?
end

t 'x { in -> }' do |it|
    it.is_a? Function_Expr and
        it.expressions.empty? and
        it.compositions.empty? and
        it.parameters.one?
end

t 'x { in, out -> 42, 24 }' do |it|
    it.is_a? Function_Expr and
        it.expressions.count == 2 and
        it.compositions.empty? and
        it.parameters.count == 2
end

t 'x { & in -> }' do |it|
    it.is_a? Function_Expr and
        it.expressions.empty? and
        it.compositions.one? and
        it.parameters.one? and
        it.parameters[0].composition
end

t '
test { abc &this = 1, def that, like = 2, &whatever  -> }
' do |it|
    it.is_a? Function_Expr and
        it.expressions.empty? and
        it.compositions.count == 2 and
        it.parameters.count == 4 and
        it.parameters[0].composition and
        not it.parameters[1].composition and
        not it.parameters[2].composition and
        it.parameters[3].composition
end

t 'func { param1, param2 -> }' do |it|
    it.is_a? Function_Expr and
        it.parameters.count == 2 and
        it.expressions.empty?
end

t 'x + y' do |it|
    it.is_a? Binary_Expr and it.left.is_a? Identifier_Expr and it.right.is_a? Identifier_Expr
end

t 'x + y * z' do |it|
    it.is_a? Binary_Expr and it.left.is_a? Identifier_Expr and it.right.is_a? Binary_Expr
end

t 'a + (b * c) - d' do |it|
    it.is_a? Binary_Expr and
        it.left.is_a? Binary_Expr and
        it.right.is_a? Identifier_Expr and
        it.left.right.is_a? Binary_Expr
end

t 'ENUM {}' do |it|
    it.is_a? Enum_Collection_Expr
end

t 'ENUM {
    ONE
}' do |it|
    it.is_a? Enum_Collection_Expr and it.constants.one?
end

t 'ENUM {
    ONE = 1
}' do |it|
    it.is_a? Enum_Collection_Expr and
        it.constants.one? and
        it.constants[0].value.is_a? Number_Literal_Expr
end

t 'ENUM {
    ONE {
        TWO = 2
    }
}' do |it|
    it.is_a? Enum_Collection_Expr and
        it.constants.one? and
        it.constants[0].is_a? Enum_Collection_Expr and
        it.constants[0].constants.one? and
        it.constants[0].constants[0].is_a? Enum_Constant_Expr
end

t 'ENUM = 1' do |it|
    it.is_a? Enum_Constant_Expr
end

t 'Abc {}' do |it|
    it.is_a? Class_Expr and
        it.block.expressions.empty? and
        it.block.compositions.empty?
end

t 'Abc > Xyz {}' do |it|
    it.is_a? Class_Expr and
        it.block.expressions.empty? and
        it.block.compositions.empty? and
        it.parent == 'Xyz'
end

t '& Abc' do |it|
    it.is_a? Composition_Expr
end

t 'self./something' do |it|
    it.is_a? Binary_Expr
end

t 'if a
}' do |it|
    it.is_a? Conditional_Expr and
        it.condition.is_a? Identifier_Expr and
        it.when_true.is_a? Block_Expr and
        it.when_false.nil?
end

t 'if a
else
}' do |it|
    it.is_a? Conditional_Expr and
        it.condition.is_a? Identifier_Expr and
        it.when_true.is_a? Block_Expr and
        it.when_false.is_a? Block_Expr
end

t 'if a
elsif 100
    yay!
else
}' do |it|
    it.is_a? Conditional_Expr and
        it.condition.is_a? Identifier_Expr and
        it.when_true.is_a? Block_Expr and
        it.when_false.is_a? Conditional_Expr and
        it.when_false.condition.is_a? Number_Literal_Expr and
        it.when_false.when_true.is_a? Block_Expr and
        it.when_false.when_true.expressions.one? and
        it.when_false.when_false.expressions.none? and
        it.when_false.when_false.is_a? Block_Expr
end

t 'while a
}' do |it|
    it.is_a? While_Expr and
        it.condition.is_a? Identifier_Expr and
        it.when_true.is_a? Block_Expr and
        it.when_false.nil?
end

t 'while a
elswhile "b"
}' do |it|
    it.is_a? While_Expr and
        it.condition.is_a? Identifier_Expr and
        it.when_true.is_a? Block_Expr and
        it.when_false.is_a? While_Expr and
        it.when_false.condition.is_a? String_Literal_Expr
end

t 'while a
elswhile 100
    yay!
else
}' do |it|
    it.is_a? While_Expr and
        it.condition.is_a? Identifier_Expr and
        it.when_true.is_a? Block_Expr and
        it.when_false.is_a? While_Expr and
        it.when_false.condition.is_a? Number_Literal_Expr and
        it.when_false.when_true.is_a? Block_Expr and
        it.when_false.when_true.expressions.one? and
        it.when_false.when_false.expressions.none? and
        it.when_false.when_false.is_a? Block_Expr
end

t 'while a > b
    x + y
}' do |it|
    it.is_a? While_Expr and
        it.condition.is_a? Binary_Expr and
        it.when_true.is_a? Block_Expr and
        it.when_true.expressions.first.is_a? Binary_Expr
end

t 'call()' do |it|
    it.is_a? Function_Call_Expr and it.arguments.empty?
end

t 'call(a)' do |it|
    it.is_a? Function_Call_Expr and it.arguments.one?
end

t 'call(a, 1, "asf")' do |it|
    it.is_a? Function_Call_Expr and it.arguments.count == 3
end

t 'call(with: a, 1, "asf")' do |it|
    it.is_a? Function_Call_Expr and it.arguments.count == 3 and it.arguments[0].label == 'with'
end

t 'call(a: 1, b, c: "str", 42)' do |it|
    it.is_a? Function_Call_Expr and
        it.arguments.count == 4 and
        it.arguments[0].label == 'a' and
        it.arguments[1].label.nil? and
        it.arguments[2].label == 'c' and
        it.arguments[3].label.nil?
end

t 'imaginary(object: Xyz {}, enum: BWAH {}, func: whatever {}, shit)' do |it|
    it.is_a? Function_Call_Expr and it.arguments.count == 4 and it.arguments[0].label and it.arguments[1].label and it.arguments[2].label and it.arguments[3].label.nil?
end

t ':test' do |it|
    it.is_a? Symbol_Literal_Expr
end

t 'Abc { & Xyz }' do |it|
    it.is_a? Class_Expr and
        it.compositions.count == 1
end

