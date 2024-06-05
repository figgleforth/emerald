# Turns string of code into tokens
class Parser
    require_relative '../lexer/tokens'
    require_relative 'nodes'

    attr_accessor :i, :buffer, :statements


    def initialize buffer = []
        @statements = []
        @buffer     = buffer
        @i          = 0 # index of current token
    end


    # region Parsing Helpers
    # makes a new Parser and sets its tokens to the current remainder
    def new_parser_with_remainder_as_buffer
        Parser.new remainder
    end


    # array of precedences, ordered by precedence. if the token provided matches one of the operator symbols in the array, then its precedence is the index of that operator symbol in the precedences array.
    def precedence_for token
        # todo: check if anything doesn't belong here, or in this language
        [
            %w(( )), # 0
            %w([ ]), # 1
            %w(!), # 2
            %w(- +), # 3 Unary minus and plus
            %w(**), # 4 Exponentiation
            %w(* / %), # 5 Multiplicative
            %w(+ -), # 6 Additive
            %w(<< >>), # 7 Shift
            %w(< <= > >=), # 8 Relational
            %w(== != === !==), # 9 Equality
            %w(&), # 10 Bitwise AND
            %w(^), # 11 Bitwise XOR
            %w(|), # 12 Bitwise OR
            %w(&&), # 13 Logical AND
            %w(||), # 14 Logical OR
            %w(?:), # 15 Ternary
            %w(= += -= *= /= %= &= |= ^= <<= >>=), # 16 Assignment
            %w(,), # 17
            %w(.),
        ].find_index do |chars|
            chars.include?(token.string)
        end
    end


    # buffer[i - 1]
    def prev
        peek -1
    end


    # buffer[i]
    def curr
        peek 0
    end


    # buffer[i..]
    def remainder
        @buffer[@i..]
    end


    # whether there are tokens remaining to be parsed
    def tokens?
        @i < (@buffer&.length || 0)
    end


    # looks at token without eating, can look backwards as well but peek index is clamped to buffer. if accumulated, returns an array of tokens. otherwise returns a single token
    def peek ahead = 0
        raise 'Parser.tokens is nil' unless buffer

        index = ahead.clamp(0, @buffer.count)
        @buffer[@i + index]
    end


    # looks ahead `count` tokens, without consuming them. cannot peek backwards
    def peek_many count = 2
        raise 'Parser.tokens is nil' unless buffer

        remainder.slice 0, count
    end


    # slices buffer until specified token, so it isn't included in the result. doesn't actually consume the buffer, you still have to do that by calling eat. easier to iterate this than fuck with the actual pointer in the buffer
    def peek_until token = "\n"
        remainder.slice_before do |t|
            t == token
        end.to_a.first
    end


    # slices buffer past specified token, so it is included in the result. doesn't actually consume the buffer, you still have to do that by calling eat. easier to iterate this than fuck with the actual pointer in the buffer
    def peek_past token = "\n"
        remainder.slice_after do |t|
            t == token
        end.to_a.first
    end


    # uses peek_until to get count of tokens until specified token, then adds that count to the buffer pointer @i
    def eat_until token = "\n"
        @i += peek_until(token).count
    end


    # uses peek_past to get count of tokens until it passes specified token, then adds that count to the buffer pointer @i
    def eat_past token = "\n"
        @i += peek_past(token).count
    end


    # checks whether the remainder buffer contains the exact sequence of tokens. if one of the arguments is an array then that token in the sequence can be either of the two. eg: ident, [:, =, :=]
    def peek? * sequence
        remainder.slice(0, sequence.count).each_with_index.all? do |token, index|
            if sequence[index].is_a? Array
                sequence[index].any? do |expected|
                    token == expected
                end
            else
                token == sequence[index]
            end
        end
    end

    # eats a specific sequence of tokens, either Token class or exact string. eg: eat StringLiteralToken, eat '.'. etc
    # idea: support sequence of elements where an element can be one of many, like the sequence [IdentifierToken, [:=, =]]
    def eat * sequence
        if sequence.nil? or sequence.empty? or sequence.one?
            eaten = curr
            @i += 1
            return eaten
        end

        [].tap do |result|
            sequence.each do |expected|
                raise "Expected #{expected} but got #{curr}" unless curr == expected
                result << curr
                @i += 1
            end
        end
    end


    # endregion

    # region Sequence Parsing

    def parse_typed_var_declaration
        VarAssignmentNode.new.tap do |node|
            tokens    = eat IdentifierToken, ':', IdentifierToken
            node.name = tokens[0]
            node.type = tokens[2]

            # eat while curr == "\s"

            if peek? '='
                eat '='
                node.value = parse_statement
            end
        end
    end


    def parse_untyped_var_declaration_or_reassignment
        VarAssignmentNode.new.tap do |node|
            tokens = eat IdentifierToken, '='
            raise 'Expected expression' if peek? "\n"

            node.name  = tokens[0]
            node.value = parse_statement
        end
    end


    def parse_inferred_var_declaration
        VarAssignmentNode.new.tap do |node|
            tokens = eat IdentifierToken, ':='
            raise 'Expected expression' if peek? "\n"

            node.name = tokens[0]

            # ( expression )
            # ""
            # number
            # identifier
            node.value = parse_statement
            # node.type = tokens[2]
        end
    end


    def parse_string_or_number_literal
        if curr == StringToken
            StringLiteralNode.new
        else
            NumberLiteralNode.new
        end.tap do |literal|
            literal.token = eat
        end
    end


    def parse_unary_expr
        UnaryExprNode.new.tap do |node|
            node.operator = eat SymbolToken
            node.operand  = parse_statement precedence_for(node.operator)
        end
    end


    def parse_object_declaration
        # if first statement of program then it's top-level object declaration
        #    obj Ident > Ident (imp Ident, ...) ({) \n
        #    (imp Ident, ...)
        #
        # otherwise
        #    obj Ident > Ident (imp Ident, ...) ({) \n
        #       (imp Ident, ...)
        #    }
        ObjectDeclNode.new.tap do |node|
            node.type = eat('obj', IdentifierToken).last

            if peek? '>', IdentifierToken
                node.base_type = eat('>', IdentifierToken).last
            end

            eat while curr == DelimiterToken # { or \n or both

            # compositions
            while peek? 'imp'
                node.compositions << eat('imp', IdentifierToken).last

                while curr == ',' and peek[0] == IdentifierToken
                    node.compositions << eat(',', IdentifierToken).last
                end

                raise "Unexpected `,` without additional compositions" if curr == ','
                eat while curr == DelimiterToken # { or \n or both
            end

            # body or empty obj termination
            if peek? %w(; }) # delimiter for empty object
                eat
            else
                eat while curr == DelimiterToken # { or \n or both
                node.statements = parse_block
                eat if peek? %w(} end)
            end
        end
    end


    def parse_block until_token = %w(} end)
        parser = Parser.new remainder
        stmts  = parser.parse until_token
        @i     += parser.i
        stmts
    end


    def parse_function_call
        def parse_args
            # Ident: Expr (,)
            # Expr (,)
            [].tap do |params|
                while peek?(Token) and curr != ')'
                    params << FuncArgNode.new.tap do |param|
                        if peek? IdentifierToken, ':' #, Token
                            param.label = eat IdentifierToken
                            eat ':'
                        end

                        param.expression = if peek? Token, ','
                            parse_block ','
                        elsif peek? Token, ')'
                            parse_block ')'
                        else
                            parse_block %w[, )]
                        end.first
                    end

                    eat if peek? ','
                end
            end
        end


        FuncCallNode.new.tap do |node|
            node.function_name = eat IdentifierToken
            eat '('
            node.arguments = parse_args
            eat ')'
        end
    end


    def parse_function_declaration
        def parse_params
            [].tap do |params|
                # Ident : Ident (,)
                # Ident Ident : Ident ... first ident here is a label
                while peek? IdentifierToken
                    params << FuncParamNode.new.tap do |param|
                        if peek? IdentifierToken, IdentifierToken
                            param.label = eat IdentifierToken
                            param.name  = eat IdentifierToken
                        else
                            param.name = eat IdentifierToken
                        end

                        if peek? ':'
                            eat ':'
                            param.type = eat IdentifierToken
                        else
                            # untyped param
                        end

                        if peek? ',' and not peek?(',', IdentifierToken)
                            raise 'Expecting param after comma in function param declaration'
                        elsif peek? ','
                            eat
                        end

                        # eat ',' if peek? ','
                    end
                end
            end
        end


        def parse_return_type
            if peek? %w(: -> >> ::), IdentifierToken
                eat # : or -> or >> or ::
                eat IdentifierToken
            end
        end


        FuncDeclNode.new.tap do |node|
            node.name = eat('fun', IdentifierToken).last

            if peek? %w(: -> >> ::), IdentifierToken
                node.return_type = parse_return_type

            elsif peek? '(' # params
                eat '('
                node.parameters = parse_params
                eat ')'
                node.return_type = parse_return_type

            elsif peek? IdentifierToken
                node.parameters  = parse_params
                node.return_type = parse_return_type

            end

            if peek? "\n" or peek? "{"
                eat while peek? DelimiterToken or peek? '{'
                node.statements = parse_block

            end

            if peek? %w(; } end)
                eat
            else
                raise 'Expected } or end' unless curr == '}' or curr == 'end'
            end
        end
    end


    # endregion

    def parse_leaf
        if peek? '('
            open_paren = eat '('
            precedence = precedence_for(open_paren)
            parse_statement(precedence).tap do
                eat ')'
            end

        elsif peek? %w({ }) # for blocks that are not handled as part of other constructs. like just a random block surrounded by { and }
            eat and nil

        elsif peek? CommentToken
            eat and nil

        elsif peek? SymbolToken and curr.respond_to?(:unary?) and curr.unary? # %w(- + ~ !)
            parse_unary_expr

        elsif peek? 'fun', IdentifierToken
            parse_function_declaration

        elsif peek? 'obj', IdentifierToken
            parse_object_declaration

        elsif peek? IdentifierToken, ':='
            parse_inferred_var_declaration

        elsif peek? IdentifierToken, ':', IdentifierToken
            parse_typed_var_declaration

        elsif peek? IdentifierToken, '='
            parse_untyped_var_declaration_or_reassignment

        elsif peek? IdentifierToken, '('
            # todo: function calls without parens
            parse_function_call

        elsif peek? StringToken or peek? NumberToken
            parse_string_or_number_literal

        elsif peek? DelimiterToken # don't care about delimiters that weren't already handled by the other cases
            eat and nil

        elsif peek? IdentifierToken
            IdentExprNode.new.tap do |node|
                node.name = eat IdentifierToken
            end

        else
            raise "\n\nUnhandled:\n\t#{curr}\n\nbuffer:\n\t#{@buffer[..5].map(&:to_s)}\n\nremainder:\n\t#{remainder.map(&:to_s)}"
        end
    end


    def parse_statement precedence = 0
        left = parse_leaf
        # return left unless left # todo: do I need this?
        # return left if curr == EOFToken

        while tokens? and curr
            break unless curr == SymbolToken and curr.binary?
            # break if curr == SymbolToken and curr.unary?

            curr_prec = precedence_for curr
            break if curr_prec <= precedence

            left = BinaryExprNode.new.tap do |node|
                node.left     = left
                node.operator = eat SymbolToken

                # todo: is this the right way to handle this? what if I want expressions on the next line? maybe some keyword like `\`?
                raise 'Expected expression' if peek? "\n"

                node.right = parse_statement curr_prec
                eat if curr == ']'
            end
        end

        left
    end


    def parse until_token = EOFToken
        @statements = []
        while tokens? and curr != EOFToken
            if until_token.is_a? Array
                break if until_token.any? do |t|
                    curr == t
                end
            else
                break if curr == until_token
            end

            @statements << parse_statement
        end
        @statements.compact
    end
end