class SyncShowPageJob < OhdioApiJob
  def perform(show_external_id, show_type, page, max_episodes = nil)
    OhdioShowSyncService.new(show_external_id: show_external_id, type: show_type, page: page, max_episodes: max_episodes).call
  end
end
