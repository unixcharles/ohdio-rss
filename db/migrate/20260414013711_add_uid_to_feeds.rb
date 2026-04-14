class AddUidToFeeds < ActiveRecord::Migration[8.1]
  class MigrationFeed < ApplicationRecord
    self.table_name = 'feeds'
  end

  def up
    add_column :feeds, :uid, :string

    MigrationFeed.reset_column_information
    MigrationFeed.find_each do |feed|
      feed.update_columns(uid: SecureRandom.hex(16))
    end

    change_column_null :feeds, :uid, false
    add_index :feeds, :uid, unique: true
  end

  def down
    remove_index :feeds, :uid
    remove_column :feeds, :uid
  end
end
