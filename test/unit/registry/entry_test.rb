require 'test/test_helper'

module Registry
  class EntryTest < ActiveRecord::TestCase

    CONFIG = "#{Rails.root}/tmp/registry.yml"

    def setup
      Dir.mkdir("#{Rails.root}/tmp") rescue nil
      File.delete(CONFIG)            rescue nil
    end

    test 'environments' do
      create_entries
      assert_equal ['dev', 'test'], Entry.environments.sort
    end

    test 'export' do
      expected = create_entries
      assert_equal expected, Entry.export!(CONFIG)
      assert_equal true, File.exists?(CONFIG), 'Export file should be created'
    end

    test 'export no file' do
      File.delete(Entry::DEFAULT_YML_LOCATION) rescue nil
      expected = create_entries
      assert_equal expected, Entry.export!(nil)
      assert_equal false, File.exists?(Entry::DEFAULT_YML_LOCATION), 'Export file should NOT be created'
    end

    test 'import does not overwrite' do
      root = Entry.root('dev')
      root.create_property(:key => 'one', :value => 'preserve')
      two = root.create_folder(:key => 'two')
      two.create_property(:key => 'one', :value => 'preserve')

      data = {
        'dev' => {
          'one' => 'new',
          'two' => {'one' => 'new', 'two' => 'new'},
          'tre' => 'new',
        },
      }
      File.open(CONFIG, 'w') do |out|
        YAML.dump(data, out)
      end

      Entry.import!(CONFIG)

      expected = {
        'dev' => {
          'one' => 'preserve',
          'two' => {'one' => 'preserve', 'two' => 'new'},
          'tre' => 'new',
        }
      }
      assert_equal expected, Entry.export!(nil)
    end

    test 'versioning' do
      prop = Entry.root.create_property(:key => 'one', :value => 'one')

      assert_difference 'Registry::Entry::Version.count', 1 do
        prop.update_attributes(:value => 'two')
      end

      prop.revert_to!(1)
      assert_equal 'one', prop.reload.value, 'Reversion failed'

      prop.update_attributes(:value => 'three')
      assert_equal 3, prop.reload.version
    end

    test 'deletes are versioned' do
      prop = Entry.root.create_property(:key => 'one', :value => 'one')

      assert_difference 'Registry::Entry::Version.count', 1 do
        assert_difference 'Registry::Entry.count', -1 do
          prop.destroy
        end
      end

      version = Registry::Entry::Version.last
      assert_match 'deleted', version.notes
    end

    test 'skip_already_deleted prevents property creation if deleted' do
      Entry.root.create_property(:key => 'one', :value => 'one').destroy

      folder = Entry.root.create_folder(:key => 'folder')
      folder.create_property(:key => 'two', :value => 'two').destroy

      assert_no_difference 'Registry::Entry.count' do
        Entry.root.merge({'one' => 'two'}, :skip_already_deleted => true)
        folder.merge({'two' => 'three'}, :skip_already_deleted => true)
      end
    end

    test 'skip_already_deleted prevents folder creation if deleted' do
      Entry.root.create_folder(:key => 'one').destroy

      folder = Entry.root.create_folder(:key => 'folder')
      folder.create_folder(:key => 'two').destroy

      assert_no_difference 'Registry::Entry.count' do
        Entry.root.merge({'one' => {'one' => 'one'}}, :skip_already_deleted => true)
        Entry.root.merge({'folder' => {'two' => {:one => 'one'}}}, :skip_already_deleted => true)
        folder.merge({'two' => {:one => 'one'}}, :skip_already_deleted => true)
      end
    end

    test 'decode' do
      entry = Registry::Entry.new
      assert_equal :foo, entry.send(:decode, ':foo')
      assert_equal 0..9, entry.send(:decode, '0..9')
      assert_equal 0..9, entry.send(:decode, '00..09')
    end

    test 'child' do
      create_entries
      assert_equal true, Entry.root.child('folder1').folder?
      assert_equal true, Entry.root.child('/folder1').folder?, 'child method should handle leading /'
      assert_equal ':symbol', Entry.root.child('folder2/:symbol').value
      assert_raise ArgumentError do
        Entry.root.child('foo/bar') 
      end
    end

  private

    def create_entries(envs=nil, folders=nil, values=nil)
      envs    ||= ['dev', 'test']
      folders ||= ['folder1', 'folder2']
      values  ||= {
        'string'  => 'string',
        false     => false,
        42        => -42,
        3.14      => -3.14,
        :symbol   => :symbol,
        'time'    => Time.parse('1968-05-21 12:59:00'),
        1 ... 10  => 1 .. 10,
        'array'   => ['string', false, -42, -3.14, :symbol, Time.parse('1968-05-21 12:59:00'), 1...10]
      }

      entries = {}

      envs.each do |env|
        entries[env] ||= {}
        root = Entry.root(env)

        folders.each do |folder|
          entries[env][folder] ||= {}
          folder = Folder.create!(:parent => root, :key => folder)

          values.each do |key, value|
            entry = Entry.create!(:parent => folder, :key => key, :value => value)
            entries[env][folder.key].store(key, value)
          end
        end
      end

      entries
    end

  end # class EntryTest
end # module Registry
