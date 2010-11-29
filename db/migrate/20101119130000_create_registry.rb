class CreateRegistry < ActiveRecord::Migration
  def self.up
    create_table :registry_entries do |t|
      t.string  :env,       :nil => false, :limit => 32
      t.integer :parent_id

      t.string  :key,       :nil => false
      t.string  :type,      :nil => false, :limit => 64
      t.string  :value,     :nil => false

      t.string  :label
      t.string  :description

      t.integer :user_id

      t.timestamps
    end

    add_index :registry_entries, [:parent_id, :key]
  end

  def self.down
    drop_table :registry_entries
  end
end
