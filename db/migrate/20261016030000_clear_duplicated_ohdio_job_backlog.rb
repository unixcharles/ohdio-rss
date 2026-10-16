# One-off cleanup for the job backlog built up while syncs failed with PersistedQueryNotFound
# (2026-10-08 → 2026-10-16): ~23k unfinished Ohdio jobs, nearly all duplicates of each other
# because nothing deduplicated enqueues. OhdioApiJob subclasses now discard duplicates, but the
# existing backlog would still take hours to drain at ~1 Ohdio call per second.
#
# Every one of these jobs is safe to drop: a fresh RefreshAllFeedsJob (enqueued below) re-syncs every
# show, which re-enqueues page, segment and audio resolution work for whatever is still missing.
#
# Runs at boot before the job workers start, so no job here is actually executing. No-op where the
# Solid Queue tables don't live in this environment (development/test).
class ClearDuplicatedOhdioJobBacklog < ActiveRecord::Migration[8.1]
  JOB_CLASSES = %w[SyncShowJob SyncShowPageJob SyncEpisodeSegmentsJob ResolveAudioContentJob RefreshAllFeedsJob].freeze
  EXECUTION_MODELS = %w[
    SolidQueue::ReadyExecution SolidQueue::BlockedExecution SolidQueue::ScheduledExecution
    SolidQueue::ClaimedExecution SolidQueue::FailedExecution
  ].freeze

  def up
    return unless solid_queue_tables?

    say_with_time "Deleting unfinished #{JOB_CLASSES.join(', ')} jobs" do
      deleted = 0
      SolidQueue::Job.where(class_name: JOB_CLASSES, finished_at: nil).in_batches(of: 1_000) do |batch|
        ids = batch.pluck(:id)
        EXECUTION_MODELS.each { |model| model.constantize.where(job_id: ids).delete_all }
        deleted += SolidQueue::Job.where(id: ids).delete_all
      end
      deleted
    end

    # Held by the old global "ohdio-api-global" limit and by jobs deleted above.
    say_with_time("Clearing concurrency semaphores") { SolidQueue::Semaphore.delete_all }

    RefreshAllFeedsJob.perform_later
  end

  def down
    # Deleted jobs are not restorable; nothing to undo.
  end

  private

  def solid_queue_tables?
    SolidQueue::Job.table_exists?
  rescue ActiveRecord::ActiveRecordError
    false
  end
end
