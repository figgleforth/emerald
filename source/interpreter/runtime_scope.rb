class Runtime_Scope
    @@block_depth = 0
    attr_accessor :depth,
                  :variables, # hash of values or expressions by identifier
                  :functions, # hash of Block_Constructs
                  :classes # hash of Class_Constructs

    def initialize
        @depth        = @@block_depth
        @@block_depth += 1
        @variables    = {}
        @functions    = {}
        @classes      = {}
    end


    def global?
        depth == 0
    end


    def decrease_depth
        @@block_depth -= 1
    end
end
