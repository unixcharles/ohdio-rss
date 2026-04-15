class RefreshAllFeedsJob < ApplicationJob
  queue_as :default

  def perform
    Feed.distinct.pluck(:show_external_id).each do |show_external_id|
      SyncShowJob.perform_later(show_external_id)
    end
  end
end
