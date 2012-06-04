require 'test/test_helper'

module Registry
  module Transcoder
    class BaseTest < ActiveSupport::TestCase

      test 'transcoding' do
        assert_round_trip [1, 'one', true, :sym],             'array transcoding failed'
        assert_round_trip false,                              'boolean false transcoding failed'
        assert_round_trip true,                               'boolean true transcoding failed'
        assert_round_trip Date.parse('2007-01-16'),           'date transcoding failed'
        assert_round_trip 3.14,                               'float transcoding failed'
        assert_round_trip 42,                                 'integer transcoding failed'
        assert_round_trip '192.168.1.1',                      'ip address string transcoding failed'
        assert_round_trip '192.168.1.1/24',                   'ip network string transcoding failed'
        assert_round_trip 1 .. 10,                            'range exclusive transcoding failed'
        assert_round_trip 1 ... 10,                           'range inclusive transcoding failed'
        assert_round_trip 'string',                           'string transcoding failed'
        assert_round_trip :sym,                               'symbol transcoding failed'
        assert_round_trip Time.parse('1968-05-21 10:59:00'),  'time transcoding failed'
      end

      test 'from_db returns value unless string' do
        assert_same self, Transcoder.from_db(self)
      end

      test 'from_db handles leading zeros in ranges' do
        assert_equal 0 .. 9, Transcoder.from_db('00 .. 09'), 'leading zero range transcoding failed'
      end

    private
      
      def assert_round_trip(value, message)
        assert_equal value, Transcoder.from_db(Transcoder.to_db(value)), message
      end

    end # class BaseTest
  end # module Transcoder
end # module Registry
