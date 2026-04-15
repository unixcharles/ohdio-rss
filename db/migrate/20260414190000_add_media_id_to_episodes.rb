class AddMediaIdToEpisodes < ActiveRecord::Migration[8.1]
  def change
    add_column :episodes, :media_id, :string
    add_index :episodes, :media_id
  end
end
