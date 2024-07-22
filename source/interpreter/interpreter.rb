require_relative '../parser/exprs'
require_relative 'scopes'
require_relative 'constructs'
require 'pp'


class Interpreter # evaluates AST and returns the result
    include Scopes
    attr_accessor :expressions, :scopes


    def initialize expressions = []
        @expressions = expressions
        @scopes      = [Global_Scope.new] # default scope
    end


    def interpret!
        output = nil
        expressions.each do |expr|
            output = evaluate expr
        end
        output
    end


    def push_scope scope
        scope.parent_scope = curr_scope
        @scopes << scope
    end


    def pop_scope
        @scopes.pop
    end


    # @return [Scope, nil]

    def curr_scope
        @scopes.last
    end


    # @return [Scope]

    def global_scope
        @scopes.first
    end


    # region Get constructs

    def get_from_scope identifier
        value = curr_scope.declarations[identifier.to_s]

        if not value # start at the next scope and traverse up the stack of scopes
            scopes.reverse_each do |next_scope|
                value = next_scope.declarations[identifier.to_s]
                break if value
            end
        end

        value
    end


    # Sets a value (likely a Construct or literal value) on the current scope
    # @return [any] The value passed in
    def set_on_scope identifier, value
        curr_scope.declarations[identifier.to_s] = value
    end


    # endregion

    def merge_scope_into_current scope
        curr_scope.declarations.merge scope.declarations
    end


    def eval_macro_command expr
        if expr.expression
            if expr.name == '!>' # log level
                puts evaluate(expr.expression)
            elsif expr.name == '!!>' # warning
                puts "WARNING: #{evaluate(expr.expression)}"
            elsif expr.name == '!!!>' # error
                puts "ERROR: #{evaluate(expr.expression)}"
            end
        else
            puts ''
        end
    end


    def eval_class_declaration expr
        # Class_Expr and Class_Construct attributes
        # :name, :block, :base_class, :compositions

        Class_Construct.new.tap do |it|
            it.name         = expr.name
            it.block        = expr.block
            it.base_class   = expr.base_class
            it.compositions = expr.compositions
            set_on_scope it.name, it
        end
    end


    def eval_block_call expr
        # todo) Come up with a way to create block signatures. This should allow for functions to share names but declare different params. The signature is not a hash, it could be a string like `greeting { name -> name }` to 'greeting(name)'.
        # Since we know the strings of the param identifiers, they should be used in the signature. So can labels, so for example `greeting { for name -> name }` could be `greeting(for)`. The label should be used in place of the param name since that is the externally visible identifier for this param anyway, so it should be in the signature.
        # This would allow for methods with shared names but different params, so `greeting { from name -> name }` becomes `greeting(from)`. And now there are two funcs with the same name greeting(for) and greeting(from). The interpreter can decide which to call based on the label. greeting(for: 'Locke') or greeting(from: 'Locke)'

        last_statement = nil # is the default return value of all blocks

        construct = get_from_scope expr.name
        if construct.is_a? Variable_Construct # eval_block_call is called when a Block_Construct needs to be evaluated. In this case, a variable's value is a Block_Construct that needs evaluating, so we have to get the Block_Construct directly from the Variable_Construct:
            construct = construct.interpreted_value
        end

        if construct.is_a? Block_Construct
            push_scope Scope.new(expr.name.string)

            # evaluates argument expression if present, otherwise the declared param expression
            construct.block.parameters.zip(expr.arguments).each do |(param, arg)|
                # Block_Param_Decl_Expr and Block_Arg_Expr
                value = if arg
                    evaluate arg.expression
                else
                    evaluate param.default_expression
                end

                # if an arg like Boo.new is evaluated, it's value is an Instance_Construct so I need to merge its guts, which are located at instance_construct.scope
                # todo) currently though, I'm re-evaluating the block that was originally used to evaluate `value` here. So this seems bad. I want the actual instance to be in this scope, not a copy of it. So this needs to really use that #merge_scope_into_current function
                if value.is_a? Instance_Construct
                    # merge_scope_into_current value.scope
                    evaluate value.class_construct.block
                end

                set_on_scope param.name, value # || Nil_Construct.new
            end

            construct.block.expressions.each do |expr_inside_block|
                last_statement = evaluate expr_inside_block
            end
            pop_scope
        else
            raise 'This will never get raised. If it does, check your logic for calling blocks'
        end

        last_statement
    end


    def eval_block expr
        last_statement = nil # the default return value of all blocks
        if expr.named? and not expr.force_evaluation # store the block on the current scope
            last_statement = Block_Construct.new.tap do |it|
                it.block     = expr
                it.name      = expr.name
                it.signature = expr.signature

                set_on_scope it.name, it
            end
        else
            # evaluate the block since it wasn't named, and therefor isn't being stored
            # todo: generalize Block_Call_Expr then use here instead for consistency
            expr.parameters.each do |it|
                # Block_Param_Decl_Expr
                set_on_scope it.name, evaluate(it.default_expression)
            end

            expr.compositions.map do |it|
                ident = it.identifier.string
                if it.operator == '&'
                    if it.identifier.string[0]&.chars&.all? { |c| c.downcase == c }
                        raise 'Cannot compose with members yet'
                    elsif it.identifier.string[0]&.chars&.all? { |c| c.upcase == c }
                        guts = get_from_scope ident
                        evaluate guts.block
                    end
                    # todo) error message when composition doesn't exist in any scope
                elsif it.operator == '~'
                else
                    raise "Interpreter#evaluate: Unknown composition operator #{it.inspect}"
                end
            end

            expr.expressions.map do |it|
                next if it.is_a? Composition_Expr # these are explicitly handled above because expressions might depend compositions being present
                last_statement = evaluate it
            end
        end
        last_statement
    end


    def eval_number_literal expr
        if expr.type == :int
            Integer(expr.string)
        elsif expr.type == :float
            if expr.decimal_position == :end
                Float(expr.string + '0')
            else
                Float(expr.string)
            end # no need to explicitly check :beginning decimal position (.1) because Float(string) can parse that
        end
    end


    def eval_unary expr
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
    end


    def eval_binary expr
        left = evaluate expr.left

        # instantiate when Class_Construct . 'new'
        if left.is_a? Class_Construct and expr.right.string == 'new'
            instance = Instance_Construct.new.tap do |it|
                it.class_construct = left

                push_scope Scope.new # because #evaluate operates on the current scope, so this ensures that the block/body of the class is evaluated in its own scope

                if left.base_class
                    guts = get_from_scope left.base_class
                    evaluate guts.block
                end

                evaluate left.block
                it.scope      = pop_scope
                it.scope.name = left.name
            end
            return instance
        end

        if left.is_a? Class_Construct and expr.operator == '.'
            raise 'Calling class functions or variables is not implemented'
        end

        # if left is an Instance_Construct, it should have a scope to push and evaluate on
        if left.is_a? Instance_Construct and expr.operator == '.'
            push_scope left.scope
            result = evaluate expr.right
            pop_scope
            return result
        end

        right = evaluate expr.right
        left  = nil if left.is_a? Nil_Construct # this has to handle Nil_Construct as well because Ruby doesn't allow `nil.send('||', right)'. FYI, setting it to nil here because `Nil_Construct || right` will always return Nil_Construct.

        # I think Ruby metaprogramming is the ideal implementation here, to avoid a giant case expression for every single operator. So the general solution is `left.send expr.operator, right`, but booleans (TrueClass/FalseClass) do not respond to #send so that won't work for that specific case. So then the new solution is to handle booleans and ranges manually, and metaprogram the rest. See scratch_59.txt
        case expr.operator
            when '+'
                if expr.left.is_a? String_Literal_Expr # because I'm relying on Ruby to concat strings, the right hand must be a string as well. So when we encounter a left that's a string, then let's just automatically convert the right to a string
                    "\"#{expr.left.string}#{right}\""

                elsif expr.right.is_a? String_Literal_Expr
                    "\"#{left}#{expr.right.string}\""

                else
                    left + right
                end

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
            when '.'
                raise "Interpreter#evaluate not implemented when Binary_Expr operator is '.'"
            else
                begin
                    left.send expr.operator, right
                rescue Exception => e
                    raise "Interpreter#evaluate when Binary_Expr, Ruby exception: #{e}"
                end

        end
    end


    def eval_assignment expr
        return_value = nil
        Variable_Construct.new.tap do |it|
            it.name       = expr.name
            it.expression = expr.expression
            return_value  = expr.expression

            # only evaluate expressions that are not blocks. blocks can be executed later
            if not expr.expression.is_a? Block_Expr
                it.interpreted_value = evaluate(expr.expression)

                return_value = it.interpreted_value
            end

            if expr.expression.is_a? Identifier_Expr # in case the variable is a all caps constant
                it.is_constant = expr.expression.constant?
            end

            set_on_scope it.name, it
        end
        return_value
    end


    def eval_while expr
        # these are kinda trippy. They loop until the condition is satisfied, and also return the last expression that was evaluated as a return value.
        output = nil
        while evaluate expr.condition
            output = evaluate expr.when_true
        end

        if expr.when_false.is_a? Conditional_Expr and output.nil?
            output = evaluate expr.when_false
        end

        output
    end


    def eval_identifier expr
        # walk up the different types of constructs – check for variable first, then function, then class. Alternate way of looking up, just an idea:
        #   if identifier is member, look up in variables first then functions
        #   if identifier is class, look up classes

        if expr.string == '@'
            return curr_scope.inspect
        end

        lookup_hash = %i(variables functions classes) # used in #get_from_scope to Runtime_Scope.send lookup_hash
        value       = nil
        while value.nil?
            hash = lookup_hash.shift
            break unless hash
            value = get_from_scope expr.string
        end

        if value.nil?
            # Some identifiers will be undefined by default, like the #new function on classes.
            # todo: improve error messaging
            if expr.member?
                raise "undefined variable or function `#{expr.string}` in scope: #{curr_scope.name}"
            elsif expr.constant?
                raise "undefined constant `#{expr.string}` in scope: #{curr_scope.name}"
            else
                raise "undefined class `#{expr.string}` in scope: #{curr_scope.name}"
            end
        end

        # todo: operator overloading! if `.` then get_from_scope(left, right). if `[]` or any other binary operator, get_from_scope(left, :functions, operator) otherwise fall back to internal implementation of those functions. Maybe we should skip the middleman and just have it be a runtime scope

        if value.is_a? Variable_Construct
            if value.interpreted_value != nil # value.interpreted_value can be boolean true or false, so check if nil instead
                value.interpreted_value
            elsif value.expression.is_a? Block_Expr
                value.expression
            else
                value
            end
        elsif value.is_a? Block_Construct
            value
        elsif value.is_a? Class_Construct
            value
        elsif value.is_a? Instance_Construct
            value
        elsif value.is_a? Construct
            evaluate value.expression
        else
            value
        end
    end


    def evaluate expr # note: issues are raised here because the REPL catches these errors and prints them nicely in color
        case expr
            when Number_Literal_Expr
                eval_number_literal expr

            when String_Literal_Expr
                expr.to_string # quotes are appended and prepended to the output in #to_string

            when Symbol_Literal_Expr
                expr.to_symbol # colon is prepended to the output in #to_symbol

            when Boolean_Literal_Expr
                expr.to_bool

            when Unary_Expr
                eval_unary expr

            when Binary_Expr # create instances when dot operator with `new`
                eval_binary expr

            when Dictionary_Literal_Expr
                # reference: https://rosettacode.org/wiki/Hash_from_two_arrays#Ruby
                value_results = expr.values.map { |val| evaluate val }
                Hash[expr.keys.zip(value_results)]

            when Conditional_Expr
                if evaluate expr.condition
                    evaluate expr.when_true
                else
                    evaluate expr.when_false
                end

            when While_Expr
                eval_while expr

            when Identifier_Expr
                eval_identifier expr

            when Assignment_Expr
                eval_assignment expr

            when Block_Expr
                eval_block expr

            when Block_Call_Expr
                eval_block_call expr

            when Class_Expr
                eval_class_declaration expr

            when Macro_Command_Expr
                eval_macro_command expr

            when Nil_Expr, nil
                Nil_Construct.new

            else
                raise "Interpreting not implemented for #{expr.class}"
        end
    end
end
