class CreateRegistry < ActiveRecord::Migration
  def self.up
    create_table :registry do |t|
      t.boolean :folder
      
      t.string  :key
      t.string  :value
      t.text    :description
      
      t.string  :default_development
      t.string  :default_test
      t.string  :default_qa
      t.string  :default_staging
      t.string  :default_production
      
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
