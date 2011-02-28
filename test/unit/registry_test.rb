require 'test/test_helper'

class RegistryTest < ActiveSupport::TestCase

  def setup
    Registry.reset(true)
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

  test 'import with testing' do
    File.open('/tmp/foo.yml', 'w+') do |file|
      reg = {
        'test' => {'api' => {'enabled' => true}}
      }
      YAML.dump(reg, file)
    end

    assert_no_difference 'Registry::Entry.count' do
      Registry.import('/tmp/foo.yml', :testing => true)
    end
    assert_equal true, Registry.api.enabled?
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
      Registry.reset # should be prevented
      assert_equal false, Registry.api.enabled?
      assert_equal 2, Registry.api.limit
    end
    assert_equal true, Registry.api.enabled?
    assert_equal 1, Registry.api.limit
  end

  test 'with preserves prevent_reset' do
     reg = {
      'api' => {
        'enabled' => true,
      },
    }
    Registry::Entry.root.merge(reg)

    assert_equal nil, Registry.prevent_reset?
    Registry.prevent_reset!
    Registry.api.with(:enabled => true) do
      # nothing
    end
    assert_equal true, Registry.prevent_reset?
  end


end # class RegistryTest
