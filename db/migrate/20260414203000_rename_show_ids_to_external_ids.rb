class RenameShowIdsToExternalIds < ActiveRecord::Migration[8.1]
  def change
    rename_column :shows, :ohdio_id, :external_id
    rename_index :shows, "index_shows_on_ohdio_id", "index_shows_on_external_id"

    rename_column :feeds, :show_id, :show_external_id
    rename_index :feeds, "index_feeds_on_show_id", "index_feeds_on_show_external_id"
  end
end
