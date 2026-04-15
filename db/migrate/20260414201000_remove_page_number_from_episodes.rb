class RemovePageNumberFromEpisodes < ActiveRecord::Migration[8.1]
  def change
    remove_column :episodes, :page_number, :integer
  end
end
