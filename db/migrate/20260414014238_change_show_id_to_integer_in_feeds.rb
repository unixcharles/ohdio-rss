class ChangeShowIdToIntegerInFeeds < ActiveRecord::Migration[8.1]
  def up
    remove_index :feeds, :show_id
    change_column :feeds, :show_id, :integer, null: false
    add_index :feeds, :show_id, unique: true
  end

  def down
    remove_index :feeds, :show_id
    change_column :feeds, :show_id, :string, null: false
    add_index :feeds, :show_id, unique: true
  end
end
