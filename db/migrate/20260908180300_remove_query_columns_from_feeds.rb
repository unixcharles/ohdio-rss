class RemoveQueryColumnsFromFeeds < ActiveRecord::Migration[8.1]
  def change
    remove_column :feeds, :episode_query, :text
    remove_column :feeds, :segment_query, :text
  end
end
