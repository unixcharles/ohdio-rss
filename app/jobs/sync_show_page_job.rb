class SyncShowPageJob < OhdioApiJob
  deduplicate_by { |show_external_id, _show_type, page, *| "#{show_external_id}-#{page}" }

  def perform(show_external_id, show_type, page, max_episodes = nil)
    OhdioShowSyncService.new(show_external_id: show_external_id, type: show_type, page: page, max_episodes: max_episodes).call
  end
end
