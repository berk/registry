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
    assert_raise NoMethodError do
      Registry.api.foo
    end
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

  test 'import' do
    File.open('/tmp/foo.yml', 'w+') do |file|
      reg = {
        'test' => {'api' => {'enabled' => true}}
      }
      YAML.dump(reg, file)
    end

    Registry.import('/tmp/foo.yml')

    assert_equal true, Registry.api.enabled?
  end

  test 'import with purge' do
    File.open('/tmp/foo.yml', 'w+') do |file|
      reg = {
        'test' => {'api' => {'enabled' => true}}
      }
      YAML.dump(reg, file)
    end

    Registry.import('/tmp/foo.yml')
    orig_root_id = Registry::Entry.root.id
    Registry.import('/tmp/foo.yml', :purge => true)

    assert_not_equal orig_root_id, Registry::Entry.root.id
  end

  test 'with' do
     reg = {
      'api' => {
        'enabled' => true,
        'limit'   => 1,
      },
    }
    Registry::Entry.root.merge(reg)

    assert_equal true, Registry.api.enabled?
    assert_equal 1, Registry.api.limit
    Registry.api.with(:enabled => false, :limit => 2) do
      assert_equal false, Registry.api.enabled?
      assert_equal 2, Registry.api.limit
    end
    assert_equal true, Registry.api.enabled?
    assert_equal 1, Registry.api.limit
  end

end # class RegistryTest
