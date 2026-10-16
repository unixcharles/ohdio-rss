# Per-show log of sync problems, surfaced on the feed page and its sync log view.
#
# Repeats of the same problem (the refresh runs every 15 minutes) bump the latest entry's
# occurrences/last_occurred_at instead of adding a row each time.
class ShowSyncError < ApplicationRecord
  KINDS = %w[sync_failed segments_failed stale].freeze
  RECENT_WINDOW = 24.hours
  RETENTION = 30.days

  belongs_to :show

  validates :kind, inclusion: { in: KINDS }
  validates :message, presence: true

  scope :newest_first, -> { order(last_occurred_at: :desc, id: :desc) }
  scope :recent, -> { where(last_occurred_at: RECENT_WINDOW.ago..) }

  def self.record!(show, kind:, message:)
    now = Time.current
    latest = show.sync_errors.where(kind: kind).newest_first.first

    if latest && latest.message == message
      latest.update!(occurrences: latest.occurrences + 1, last_occurred_at: now)
    else
      show.sync_errors.create!(kind: kind, message: message, last_occurred_at: now)
      show.sync_errors.where(last_occurred_at: ...RETENTION.ago).delete_all
    end
  end

  # Logging must never be what breaks a sync job.
  def self.safely_record(show, kind:, message:)
    record!(show, kind: kind, message: message)
  rescue StandardError => e
    Rails.logger.error("[ShowSyncError] could not record #{kind} for show ##{show&.id}: #{e.class}: #{e.message}")
  end
end
