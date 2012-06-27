require 'test/test_helper'

module Registry
  module Transcoder
    class DSLTest < ActiveSupport::TestCase

      test 'matches? returns false by default' do
        assert !instance.matches?(1)
      end

      test 'matches configures matches? method' do
        instance.matches { |value| value.is_a?(Integer) }
        assert  instance.matches?(1)
        assert !instance.matches?(3.14)
      end

      test 'to_db returns to_s by default' do
        assert_equal '3.14', instance.to_db(3.14)
      end

      test 'to_db macro configures to_db method' do
        instance.to_db { |value| value.to_s }
        assert_equal '1', instance.to_db(1)
      end

      test 'from_db returns value by default' do
        string = '3.14'
        assert_same string, instance.from_db(string)
      end

      test 'from_db macro configures from_db method' do
        instance.from_db { |value| value.to_i }
        assert_equal 1, instance.from_db('1')
      end

    private
      
      def instance
        @instance ||= DSL.new
      end

    end # class DSLTest
  end # module Transcoder
end # module Registry
