class SyncShowJob < OhdioApiJob
  def perform(show_id)
    max_episodes = effective_max_episodes(show_id)
    show_record, fetched_show = OhdioShowSyncService.new(show_id: show_id, max_episodes: max_episodes).call
    enqueue_remaining_pages(show_record, fetched_show, max_episodes)
  end

  private

  def enqueue_remaining_pages(show_record, fetched_show, max_episodes)
    total_pages = total_pages_for(fetched_show, max_episodes)
    return if total_pages <= 1

    show_type = show_record.ohdio_type
    (2..total_pages).each do |page|
      SyncShowPageJob.perform_later(show_record.ohdio_id, show_type, page, max_episodes)
    end
  end

  def total_pages_for(fetched_show, max_episodes)
    page_size = fetched_show.page_size.to_i
    total_episodes = fetched_show.total_episodes.to_i
    requested_episodes = [ total_episodes, max_episodes.to_i ].min
    return 1 if page_size <= 0 || requested_episodes <= 0

    (requested_episodes.to_f / page_size).ceil
  end

  def effective_max_episodes(show_id)
    configured = Feed.where(show_id: show_id).maximum(:max_episodes).to_i
    configured = Feed::DEFAULT_MAX_EPISODES if configured <= 0

    [ configured, Feed::MAX_MAX_EPISODES ].min
  end
end
