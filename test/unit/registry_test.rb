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

  test 'exists' do
    reg = {
      'api' => {
        'enabled' => true
      },
    }
    Registry::Entry.root.merge(reg)

    assert_equal true,  Registry.exists?(:api)
    assert_equal true,  Registry.exists?('api')
    assert_equal false, Registry.exists?(:notexist)
    assert_equal false, Registry.exists?('notexist')
    assert_equal true,  Registry.api.exists?(:enabled)
    assert_equal true,  Registry.api.exists?(:enabled?)
    assert_equal true,  Registry.api.exists?(:enabled=)
    assert_equal false, Registry.api.exists?(:notexist)
    assert_equal false, Registry.api.exists?(:notexist?)
    assert_equal false, Registry.api.exists?(:notexist=)
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

    # 3 comes from test, test/api, test/api/enabled
    assert_difference 'Registry::Entry.count', 3 do
      Registry.import('/tmp/foo.yml')
    end

    assert_equal true, Registry.api.enabled?
  end

  test 'import with defaults' do
    File.open('/tmp/foo.yml', 'w+') do |file|
      YAML.dump(registry_hash_with_defaults, file)
    end

    # 8 comes from: test, test/unchanged, test/unchanged/string,
    #               test/changable, test/changeable/string, test/changeable/symbol
    #               test/new, test/new/string
    assert_difference 'Registry::Entry.count', 8 do
      Registry.import('/tmp/foo.yml')
    end

    expected = {
      'unchanged' => {
        'string' => 'default',
      },
      'changable' => {
        'string' => 'test',
        'symbol' => :symbol,
      },
      'new' => {
        'string' => 'new',
      },
    }
    assert_equal expected, Registry.to_hash
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
      assert_equal 'true', Registry::Entry.root.child('api/enabled').value, 'with should not update table'
      assert_equal '1', Registry::Entry.root.child('api/limit').value, 'with should not update table'
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

  test 'registry updates via console' do
    reg = {
      'api' => {
        'enabled' => true,
      },
    }
    Registry::Entry.root.merge(reg)

    Registry.api.enabled = false
    assert_equal 'false', Registry::Entry.root.child('api/enabled').value
  end

  test 'registry versions via console' do
    reg = {
      'api' => {
        'enabled' => true,
      },
    }
    Registry::Entry.root.merge(reg)
    assert_equal 1, Registry.versions('api/enabled').size
    Registry.api.enabled = false
    assert_equal 2, Registry.versions('api/enabled').size
  end

  test 'reset_interval reset_proc and should_reset' do
    Registry.configure do |cfg| 
      cfg.reset_interval = 1.second
    end

    Registry.reset
    assert !Registry.should_reset?
    sleep 2
    assert  Registry.should_reset?
  end

private

  def registry_hash_with_defaults
    {
      Registry::DEFAULTS_KEY => {
        'unchanged' => {
          'string'  => 'default',
        },
        'changable' => {
          'string'  => 'default',
        },
      },
      'test' => {
        'changable' => {
          'string'  => 'test',
          'symbol'  => ':symbol',
        },
        'new' => {
          'string'  => 'new',
        },
      },
    }
  end

end # class RegistryTest
