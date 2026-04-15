class RemovePositionFromEpisodes < ActiveRecord::Migration[8.1]
  def change
    remove_index :episodes, [ :show_id, :position ], if_exists: true
    remove_column :episodes, :position, :integer
  end
end
