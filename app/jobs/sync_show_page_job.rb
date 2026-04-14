class SyncShowPageJob < OhdioApiJob
  def perform(show_id, show_type, page, max_episodes = nil)
    OhdioShowSyncService.new(show_id: show_id, type: show_type, page: page, max_episodes: max_episodes).call
  end
end
