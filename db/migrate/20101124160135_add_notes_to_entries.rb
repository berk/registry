class AddNotesToEntries < ActiveRecord::Migration
  def self.up
    add_column :registry_entries, :notes, :text
    add_column :registry_entry_versions, :notes, :text
  end

  def self.down
    remove_column :registry_entries, :notes
    remove_column :registry_entry_versions, :notes
  end
end
