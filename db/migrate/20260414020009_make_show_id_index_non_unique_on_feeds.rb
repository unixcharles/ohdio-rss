class MakeShowIdIndexNonUniqueOnFeeds < ActiveRecord::Migration[8.1]
  def up
    remove_index :feeds, :show_id
    add_index :feeds, :show_id
  end

  def down
    remove_index :feeds, :show_id
    add_index :feeds, :show_id, unique: true
  end
end
