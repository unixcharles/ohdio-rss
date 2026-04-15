class SyncShowJob < OhdioApiJob
  def perform(show_external_id)
    max_episodes = effective_max_episodes(show_external_id)
    show_record, fetched_show, sync_summary = OhdioShowSyncService.new(show_external_id: show_external_id, max_episodes: max_episodes).call
    enqueue_remaining_pages(show_record, fetched_show, max_episodes, sync_summary)
  end

  private

  def enqueue_remaining_pages(show_record, fetched_show, max_episodes, sync_summary)
    return unless page_had_any_change?(sync_summary)

    total_pages = total_pages_for(fetched_show, max_episodes)
    return if total_pages <= 1

    show_type = show_record.ohdio_type
    (2..total_pages).each do |page|
      SyncShowPageJob.perform_later(show_record.external_id, show_type, page, max_episodes)
    end
  end

  def total_pages_for(fetched_show, max_episodes)
    page_size = fetched_show.page_size.to_i
    total_episodes = fetched_show.total_episodes.to_i
    requested_episodes = [ total_episodes, max_episodes.to_i ].min
    return 1 if page_size <= 0 || requested_episodes <= 0

    (requested_episodes.to_f / page_size).ceil
  end

  def effective_max_episodes(show_external_id)
    configured = Feed.where(show_external_id: show_external_id).maximum(:max_episodes).to_i
    configured = Feed::DEFAULT_MAX_EPISODES if configured <= 0

    [ configured, Feed::MAX_MAX_EPISODES ].min
  end

  def page_had_any_change?(sync_summary)
    return true if sync_summary.nil?

    sync_summary.fetch(:page_had_any_change, true)
  end
end
