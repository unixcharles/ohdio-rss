# Seeds the new sync log with the last error each show already recorded in shows.sync_error, so
# shows that were failing before the log existed (e.g. emissions hit by PersistedQueryNotFound
# since 2026-10-08) show up in it right away.
class BackfillShowSyncErrors < ActiveRecord::Migration[8.1]
  class MigrationShow < ActiveRecord::Base
    self.table_name = "shows"
  end

  class MigrationShowSyncError < ActiveRecord::Base
    self.table_name = "show_sync_errors"
  end

  def up
    MigrationShow.where.not(sync_error: [ nil, "" ]).find_each do |show|
      MigrationShowSyncError.create!(
        show_id: show.id,
        kind: "sync_failed",
        message: show.sync_error,
        last_occurred_at: show.updated_at,
        created_at: show.updated_at
      )
    end
  end

  def down
    MigrationShowSyncError.delete_all
  end
end
