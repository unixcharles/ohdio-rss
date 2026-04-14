class RefreshAllFeedsJob < ApplicationJob
  queue_as :default

  def perform
    Feed.distinct.pluck(:show_id).each do |show_id|
      SyncShowJob.perform_later(show_id)
    end
  end
end
