class AddMaxEpisodesToFeeds < ActiveRecord::Migration[8.1]
  def change
    add_column :feeds, :max_episodes, :integer, null: false, default: 100
  end
end
