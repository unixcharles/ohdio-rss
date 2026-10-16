class SyncEpisodeSegmentsJob < OhdioApiJob
  deduplicate_by { |episode_id, *| episode_id.to_s }

  def perform(episode_id, page_hint = nil, max_episodes = nil)
    episode = Episode.find_by(id: episode_id)
    return if episode.nil?

    OhdioEpisodeSegmentSyncService.new(
      episode: episode,
      page_hint: page_hint,
      max_episodes: max_episodes
    ).call
  end
end
