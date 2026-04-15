class AddHighestMaxEpisodesToShows < ActiveRecord::Migration[8.1]
  def change
    add_column :shows, :highest_max_episodes, :integer
  end
end
