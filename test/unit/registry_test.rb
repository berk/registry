require 'test/test_helper'

class RegistryTest < ActiveSupport::TestCase

  def setup
    Registry.reset
  end

  test 'method_missing' do
    reg = {
      'api' => {
        'enabled' => true,
        'limit'   => 1,
      },
    }
    Registry::Entry.root.merge(reg)

    assert_equal true, Registry.api?
    assert_equal true, Registry.api.enabled?
    assert_equal 1, Registry.api.limit
    assert_equal nil, Registry.api.foo
  end

  test 'to_hash' do
    reg = {
      'foo' => {
        :default => :one,
         0 ..  9 => :two,
        20 .. 29 => :three,
      },
    }
    Registry::Entry.root.merge(reg)

    assert_equal reg['foo'], Registry.foo.to_hash
  end

end # class RegistryTest
