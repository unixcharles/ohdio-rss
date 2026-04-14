class AddEpisodeQueryToFeeds < ActiveRecord::Migration[8.1]
  def change
    add_column :feeds, :episode_query, :text
  end
end
