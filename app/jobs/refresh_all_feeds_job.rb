class RefreshAllFeedsJob < ApplicationJob
  queue_as :default

  # A refresh that hasn't run yet already covers every show; don't stack another one behind it.
  limits_concurrency to: 1, key: -> { "all" }, duration: 1.hour, on_conflict: :discard

  def perform
    Feed.distinct.pluck(:show_external_id).each do |show_external_id|
      SyncShowJob.perform_later(show_external_id)
    end
  end
end
