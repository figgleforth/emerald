require_relative '../parser/ast'
require_relative 'runtime_scope'
require_relative 'constructs'


class Interpreter # evaluates AST and returns the result
    attr_accessor :expressions, :scopes


    def initialize expressions = []
        @expressions = expressions
        @scopes      = [Runtime_Scope.new] # default runtime scope
    end


    def interpret!
        output = nil
        expressions.each do |expr|
            output = evaluate expr # expressions.first
        end
        output
    end


    def depth
        @scopes.count
    end


    def push_scope scope
        @scopes << scope
    end


    def pop_scope
        curr_scope.decrease_depth if curr_scope
        @scopes.pop
    end


    # @return [Runtime_Scope, nil]
    def curr_scope
        @scopes.last
    end


    # @return [Runtime_Scope]
    def global_scope
        @scopes.first || Runtime_Scope.new
    end


    # region Get constructs

    def get_construct type, identifier
        value = curr_scope.send(type)[identifier.to_s]

        if not value
            # start at the next scope and reverse the scopes array so we can traverse up the stack easier
            depth = 0
            scopes.reverse!
            while value.nil?
                depth      += 1
                next_scope = scopes[depth]
                break unless next_scope
                value = next_scope.send(type)[identifier.to_s]
            end
            scopes.reverse! # put it back in the proper order
        end

        value
    end


    def set_construct type, identifier, construct
        curr_scope.send(type)[identifier.to_s] = construct
        construct
    end


    # endregion

    def evaluate expr # note: issues are raised here because the REPL catches these errors and prints them nicely in color
        case expr
            when Number_Literal_Expr
                if expr.type == :int
                    Integer(expr.string)
                elsif expr.type == :float
                    if expr.decimal_position == :end
                        Float(expr.string + '0')
                    else
                        Float(expr.string)
                    end # no need to explicitly check :beginning decimal position (.1) because Float(string) can parse that
                end

            when String_Literal_Expr
                expr.string.inspect # note: using #inspect so that the output contains the quotes

            when Symbol_Literal_Expr
                expr.to_ruby_symbol

            when Boolean_Literal_Expr
                expr.to_bool

            when Unary_Expr
                value = evaluate(expr.expression)
                case expr.operator
                    when '-'
                        -value
                    when '+'
                        +value
                    when '~'
                        ~value
                    when '!'
                        !value
                    else
                        raise "#evaluate Unary_Expr(#{operator.inspect}) is not implemented"
                end

            when Binary_Expr
                left  = evaluate expr.left
                right = evaluate expr.right
                left  = nil if left.is_a? Nil_Construct # this has to handle Nil_Construct as well because Ruby doesn't allow `nil.send('||', right)'. FYI, setting it to nil here because Nil_Construct || right will always return Nil_Construct.

                # I think Ruby metaprogramming is the ideal implementation here, to avoid a giant case expression for every single operator. So the general solution is `left.send expr.operator, right`, but booleans (TrueClass/FalseClass) do not respond to #send so that won't work as is. So the new solution is to handle booleans and ranges manually, and metaprogram the rest. See scratch_59.txt
                case expr.operator
                    when '+'
                        left + right
                    when '-'
                        left - right
                    when '*'
                        left * right
                    when '/'
                        left / right
                    when '%'
                        left % right
                    when '**'
                        left ** right
                    when '<<'
                        left << right
                    when '>>'
                        left >> right
                    when '<='
                        left <= right
                    when '>='
                        left >= right
                    when '<'
                        left < right
                    when '>'
                        left > right
                    when '=='
                        left == right
                    when '||'
                        left || right
                    when '&&'
                        left && right
                    when '.<', '..'
                        Range_Construct.new.tap do |it|
                            it.left     = left
                            it.right    = right
                            it.operator = expr.operator
                        end
                    else
                        begin
                            left.send expr.operator, right
                        rescue Exception => e
                            raise "Interpreter#evaluate when Binary_Expr, Ruby exception: #{e}"
                        end

                end

            when Dictionary_Literal_Expr
                # reference: https://rosettacode.org/wiki/Hash_from_two_arrays#Ruby
                value_results = expr.values.map { |val| evaluate val }
                Hash[expr.keys.zip(value_results)]

            when Identifier_Expr
                # Walk up the different types of constructs. Basically check for variable first, then function, then object. todo: I think this can be improved in a way that we don't have to walk up, and instead check expr.string.member? or .object?. But I don't know, just a hunch

                types     = %i(variables functions objects)
                construct = nil
                while construct.nil?
                    type = types.shift
                    break unless type
                    construct = get_construct type, expr.string
                end

                if construct.nil?
                    raise "Undefined `#{expr.string}`" # todo: improve error messaging
                end

                if construct.is_a? Variable_Construct
                    if construct.result != nil # construct.result can be boolean true or false, so check if nil instead
                        construct.result
                    elsif construct.expression.is_a? Block_Expr
                        construct.expression
                    end
                elsif construct.is_a? Block_Construct or construct.is_a? Class_Construct
                    construct
                elsif construct.is_a? Construct
                    evaluate construct.expression
                else
                    construct
                end

            when Assignment_Expr
                return_value = nil
                Variable_Construct.new.tap do |it|
                    it.name       = expr.name
                    it.expression = expr.expression
                    return_value  = expr.expression

                    if not expr.expression.is_a? Block_Expr # only evaluate non-blocks
                        it.result    = evaluate(expr.expression)
                        return_value = it.result
                    end

                    if expr.expression.is_a? Identifier_Expr # in case the variable is a all caps constant
                        it.is_constant = expr.expression.constant?
                    end

                    set_construct :variables, it.name, it
                end
                return_value

            when Block_Expr
                last_statement = nil # the default return value of all blocks
                if expr.named? # store the block on the current scope
                    last_statement = Block_Construct.new.tap do |it|
                        it.block     = expr
                        it.name      = expr.name
                        it.signature = expr.signature

                        set_construct :functions, it.name, it
                    end
                else
                    # evaluate the block since it wasn't named, and therefor isn't being stored
                    # todo: generalize Block_Call_Expr then use here instead for consistency
                    push_scope Runtime_Scope.new
                    expr.parameters.each do |it|
                        # Block_Param_Decl_Expr
                        set_construct :variables, it.name, evaluate(it.default_value)
                    end

                    expr.expressions.map do |expr_inside_block|
                        last_statement = evaluate expr_inside_block
                    end
                    pop_scope
                end
                last_statement

            when Block_Call_Expr
                # Come up with a way to create block signatures. This should allow for functions to share names but declare different params. The signature is not a hash, it could be a string like func1 { a -> } to 'func1->a'. Or something like that, not sure yet.

                last_statement = nil # is the default return value of all blocks

                construct = get_construct :functions, expr.name
                if construct # is a Block_Construct
                    push_scope Runtime_Scope.new

                    # evaluates argument expression if present, otherwise the declared param expression
                    construct.block.parameters.zip(expr.arguments).each do |(param, argument)|
                        # Block_Param_Decl_Expr and Block_Arg_Expr
                        value = if argument
                            evaluate argument.expression
                        else
                            evaluate param.default_value
                        end

                        set_construct :variables, param.name, value
                    end

                    construct.block.expressions.each do |expr_inside_block|
                        last_statement = evaluate expr_inside_block # expressions.first
                    end
                    pop_scope
                else
                    # when blocks are stored in variables, they can be evaluated later as long as a method by the same name doesn't already exist? This doesn't seem right
                    construct = get_construct :variables, expr.name
                    if construct and construct.expression.is_a? Block_Expr
                        push_scope Runtime_Scope.new
                        construct.expression.expressions.map do |block_expr|
                            last_statement = evaluate block_expr
                        end
                        pop_scope
                    else
                        raise "Undefined `#{expr.name}`"
                    end

                end

                last_statement

            when Class_Expr
                Class_Construct.new.tap do |it|
                    it.name         = expr.name
                    it.block        = expr.block
                    it.base_class   = expr.base_class
                    it.compositions = expr.compositions
                    set_construct :objects, it.name, it
                end

            when Nil_Expr, nil
                Nil_Construct.new

            else
                raise "Interpreting not implemented for #{expr.class}"
        end
    end
end
