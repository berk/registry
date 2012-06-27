module Registry
  module Transcoder
    class DSL < Base

      def matches(&block)
        matches?(&block)
      end

      def matches?(value=nil, &block)
        if block_given?
          @match_block = block
        elsif @match_block
          @match_block.call(value)
        else
          super   
        end
      end

      def to_db(value=nil, &block)
        if block_given?
          @to_db_block = block
        elsif @to_db_block
          @to_db_block.call(value)
        else
          super
        end
      end

      def from_db(string=nil, &block)
        if block_given?
          @from_db_block = block
        elsif @from_db_block
          @from_db_block.call(string)
        else
          super
        end
      end

    end # class DSL
  end # module Transcoder
end # module Registry
