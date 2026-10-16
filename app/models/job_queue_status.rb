# Snapshot of the background job queue, shown on the sync log page so a stuck or growing queue is
# visible without shell access to the server. Nil where Solid Queue isn't the job backend
# (development/test).
module JobQueueStatus
  Snapshot = Data.define(:unfinished_by_class, :failed, :oldest_unfinished_at)

  def self.snapshot
    return nil unless SolidQueue::Job.table_exists?

    unfinished = SolidQueue::Job.where(finished_at: nil)
    Snapshot.new(
      unfinished_by_class: unfinished.group(:class_name).order(count_all: :desc).count,
      failed: SolidQueue::FailedExecution.count,
      oldest_unfinished_at: unfinished.where.not(class_name: "SolidQueue::RecurringJob").minimum(:created_at)
    )
  rescue ActiveRecord::ActiveRecordError
    nil
  end
end
