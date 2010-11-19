ENV['RAILS_ENV'] = 'test'
require File.expand_path(File.dirname(__FILE__) + '/../config/environment')
require 'test_help'

class ActiveSupport::TestCase
  # Add more helper methods to be used by all tests here...

  def assert_hash(expected, result, so_far=nil)
    diff = expected.keys - result.keys
    assert_equal [], diff, "Expected Keys missing#{so_far && " from: #{so_far}"}"

    diff = result.keys - expected.keys
    assert_equal [], diff, "Unexpected Keys present#{so_far && " in: #{so_far}"}"

    expected.keys.each do |key|
      if expected[key].is_a?(Hash)
        assert_hash(expected[key], result[key], "#{so_far}#{key}/")
      elsif expected[key] == '__any__'
        assert result.key?(key), "#{so_far}#{key} expected"
      else
        assert_equal expected[key], result[key], "#{so_far}#{key} mismatch"
      end
    end
  end

end
