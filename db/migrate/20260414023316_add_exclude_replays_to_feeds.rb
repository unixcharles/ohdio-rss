class AddExcludeReplaysToFeeds < ActiveRecord::Migration[8.1]
  def change
    add_column :feeds, :exclude_replays, :boolean, default: true, null: false
  end
end
