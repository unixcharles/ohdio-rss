class SyncEpisodeSegmentsJob < OhdioApiJob
  def perform(episode_id)
    episode = Episode.find_by(id: episode_id)
    return if episode.nil?

    OhdioEpisodeSegmentSyncService.new(episode: episode).call
  end
end
