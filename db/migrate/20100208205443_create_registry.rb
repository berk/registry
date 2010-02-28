class CreateRegistry < ActiveRecord::Migration
  def self.up
    create_table :registry do |t|
      t.boolean :folder
      
      t.string  :key
      t.string  :label
      t.text    :description
      
      t.string  :development_value
      t.string  :test_value
      t.string  :qa_value
      t.string  :staging_value
      t.string  :production_value
      
      t.integer :parent_id, :limit => 8
      t.string  :updater_type
      t.integer :updater_id, :limit => 8
      
      t.timestamps
    end
    
    add_index :registry, [:parent_id]
    add_index :registry, [:key]
    add_index :registry, [:updater_type, :updater_id]
  end

  def self.down
    drop_table :registry
  end
end
