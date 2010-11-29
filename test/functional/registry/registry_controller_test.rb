require 'test/test_helper.rb'

class Registry::RegistryControllerTest < ActionController::TestCase

  def setup
    @root = Registry::Entry.root
  end

  test 'index' do
    get :index
    assert_response :success
    assert_select 'iframe[src=/registry/viewport]'
  end

  test 'viewport' do
    get :viewport
    assert_response :success
  end

  test 'delete_folder successful' do
    folder = Registry::Folder.create!(:parent => @root, :key => 'folder')

    assert_difference 'Registry::Folder.count', -1 do
      get :delete_folder, :node => folder.id
      assert_response :success
      assert_equal 'done', @response.body
    end
  end

  test 'delete_folder failed' do
    folder = Registry::Folder.create!(:parent => @root, :key => 'folder')
    assert_no_difference 'Registry::Folder.count' do
      get :delete_folder, :node => 42
      assert_response :success
      assert_equal 'done', @response.body
    end
  end

  test 'folders' do
    folder = Registry::Folder.create!(:parent => @root, :key => 'folder', :label => 'Label')
    get :folders, :node => folder.parent.id
    assert_response :success
    expected = [{'id' => folder.id.to_s, 'key' => 'folder', 'label' => 'Label', 'text' => 'Label', 'cls' => 'folder'}]
    assert_equal expected, JSON.parse(@response.body)
  end

  test 'folder' do
    get :folder, :folder_id => @root
    assert_response :success
    expected = {
      'total'       => 1,
      'success'     => true,
      'folders'  => [{'id' => @root.id.to_s, 'key' => @root.key, 'label' => @root.label, 'text' => @root.label, 'cls' => 'folder'}]
    }
    assert_equal expected, JSON.parse(@response.body)
  end

  test 'folder creation' do
    with_login do |user|
      assert_difference 'Registry::Folder.count', 1 do
        post :folder, :folder_id => 'xnode-123', :folder => {:label => 'Label', :key => 'key'}, :parent_id => @root.id
        assert_response :success
      end
      expected = {
        'total'       => 1,
        'success'     => true,
        'folders'  => [{'id' => @root.folders.first.id.to_s, 'key' => 'key', 'label' => 'Label', 'text' => 'Label', 'cls' => 'folder'}]
      }
      assert_equal expected, JSON.parse(@response.body)
      folder = Registry::Folder.last
      assert_equal user.class.name, folder.user_type
      assert_equal user.id, folder.user_id
    end
  end

  test 'folder update' do
    with_login do |user|
      child = Registry::Folder.create!(:parent => @root, :key => 'key', :label => 'label', :user => user)
      assert_no_difference 'Registry::Folder.count' do
        post :folder, :folder_id => child.id, :folder => {:id => child.id, :label => 'Label', :key => 'Key'}, :parent_id => @root.id
        assert_response :success
      end
      child.reload
      assert_equal 'Key', child.key
      assert_equal 'Label', child.label
      expected = {
        'total'       => 1,
        'success'     => true,
        'folders'  => [{'id' => child.id.to_s, 'key' => 'Key', 'label' => 'Label', 'text' => 'Label', 'cls' => 'folder'}]
      }
      assert_equal expected, JSON.parse(@response.body)
      assert_equal user.class.name, child.user_type
      assert_equal user.id, child.user_id
    end
  end

  test 'property' do
    assert_no_difference 'Registry::Entry.count' do
      get :property
      assert_response :success
    end
    expected = {
      'total'       => 1,
      'success'     => true,
      'properties'  => [{'label' => '', 'value' => '', 'description' => '', 'key' => ''}]
    }
    assert_equal expected, JSON.parse(@response.body)
  end

  test 'property creation' do
    with_login do |user|
      assert_difference 'Registry::Entry.count', 1 do
        post :property, :parent_id => @root.id, :property => {:label => 'Label', :key => 'key', :value => 'value', :description => 'Description'}
        assert_response :success
      end
      expected = {
        'total'       => 1,
        'success'     => true,
        'properties'  => [{'label' => 'Label', 'value' => 'value', 'description' => 'Description', 'key' => 'key'}]
      }
      assert_equal expected, JSON.parse(@response.body)
      entry = Registry::Entry.last
      assert_equal user.class.name, entry.user_type
      assert_equal user.id, entry.user_id
    end
  end

  test 'property update' do
    with_login do |user|
      child = Registry::Entry.create!(:parent => @root, :key => 'key', :value => 'value', :label => 'label', :description => 'description')
      assert_no_difference 'Registry::Folder.count' do
        post :property, :parent_id => @root.id, :prop_id => child.id, :property => {:key => 'Key', :value => 'Value', :label => 'Label', :description => 'Description'}
        assert_response :success
      end
      child.reload
      assert_equal 'Key', child.key
      assert_equal 'Label', child.label
      expected = {
        'total'       => 1,
        'success'     => true,
        'properties'  => [{'key' => 'Key', 'value' => 'Value', 'label' => 'Label', 'description' => 'Description'}]
      }
      assert_equal expected, JSON.parse(@response.body)
      entry = Registry::Entry.last
      assert_equal user.class.name, entry.user_type
      assert_equal user.id, entry.user_id
    end
  end

  test 'properties get' do
    one = Registry::Entry.create!(:parent => @root, :key => 'one', :value => '1')
    two = Registry::Entry.create!(:parent => @root, :key => 'two', :value => '2')
    get :properties
    assert_response :success
    expected = {
      'total'       => 2,
      'success'     => true,
      'properties'  => [
        {'id' => one.id.to_s, 'key' => 'one', 'value' => '1', 'label' => 'one', 'description' => '', 'access_code' => 'Registry.one'},
        {'id' => two.id.to_s, 'key' => 'two', 'value' => '2', 'label' => 'two', 'description' => '', 'access_code' => 'Registry.two'},
      ]
    }
    assert_equal expected, JSON.parse(@response.body)
  end

  test 'properties put' do
    with_login do |user|
      one = Registry::Entry.create!(:parent => @root, :key => 'one', :value => '1')
      put :properties, :properties => {:id => one.id, :value => '2', :label => 'discarded'}
      assert_response :success
      expected = {
        'total'       => 1,
        'success'     => true,
        'properties'  => [
          {'id' => one.id.to_s, 'key' => 'one', 'value' => '2', 'label' => 'one', 'description' => '', 'access_code' => 'Registry.one'},
        ]
      }
      assert_equal expected, JSON.parse(@response.body)
      entry = Registry::Entry.last
      assert_equal user.class.name, entry.user_type
      assert_equal user.id, entry.user_id
    end
  end

  test 'properties delete' do
    with_login do |user|
      one = Registry::Entry.create!(:parent => @root, :key => 'one', :value => '1')
      assert_difference 'Registry::Entry.count', -1 do
        delete :properties, :properties => one.id
        assert_response :success
      end
      expected = {
        'total'       => 0,
        'success'     => true,
        'properties'  => []
      }
      assert_equal expected, JSON.parse(@response.body)
      entry = Registry::Entry::Version.last
      assert_equal user.class.name, entry.user_type
      assert_equal user.id, entry.user_id
    end
  end

  test 'export' do
    one = Registry::Entry.create!(:parent => @root, :key => 'one', :value => '1')
    get :export
    assert_response :success
  end

  test 'import' do
    File.open("#{Rails.root}/config/registry.yml", 'w') do |file|
      YAML.dump({'test' => {':one' => 0 .. 5}}, file)
    end
    assert_difference 'Registry::Entry.count', 1 do
      get :import
      assert_redirected_to :action => :viewport
    end
    assert_equal ':one', @root.children.first.key
    assert_equal '0..5', @root.children.first.value
  end

  test 'permission checking configuration' do
    Registry.configure do |config|
      config.permission_check {redirect_to '/foo' and return false}
    end

    get :index
    assert_redirected_to '/foo'

    Registry.configure do |config|
      config.permission_check
    end

    get :index
    assert_response :success
  end

  test 'layout configuration' do
    Registry.configure do |config|
      config.layout = 'foo'
    end

    assert_raise ActionView::MissingTemplate do
      get :index
    end

    Registry.configure do |config|
      config.layout = nil
    end
 end

 test 'user configuration' do
    user = OpenStruct.new(:id => 42)
    Registry.configure do |config|
      config.user { user }
    end

    assert_equal user, @controller.send(:registry_user)

    Registry.configure do |config|
      config.user
    end

    assert_raise NoMethodError do
      @controller.send(:registry_user)
    end
 end

end
