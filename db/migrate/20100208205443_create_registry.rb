class CreateRegistry < ActiveRecord::Migration
  def self.up
    create_table :registry do |t|
      t.boolean :folder
      
      t.string  :access_key
      t.text    :env
      t.text    :value

      t.string  :label
      t.text    :description
      
      t.integer :parent_id, :limit => 8
      t.string  :updater_type
      t.integer :updater_id, :limit => 8
      
      t.timestamps
    end
    
    add_index :registry, [:access_key, :env]
    add_index :registry, [:parent_id]
    add_index :registry, [:updater_type, :updater_id]
  end

  def self.down
    drop_table :registry
  end
end
