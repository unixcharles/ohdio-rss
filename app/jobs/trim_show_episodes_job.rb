class TrimShowEpisodesJob < ApplicationJob
  queue_as :default

  ORPHAN_AUDIO_CONTENT_DELETE_DELAY = 7.days

  def perform(show_id)
    show = Show.find_by(id: show_id)
    return if show.nil?

    ids_to_keep = show.episodes.newest_first.limit(Feed::MAX_MAX_EPISODES).select(:id)
    episodes_to_trim = show.episodes.where.not(id: ids_to_keep)
    return if episodes_to_trim.empty?

    audio_content_external_ids = Segment.where(episode_id: episodes_to_trim.select(:id)).where.not(audio_content_external_id: nil).distinct.pluck(:audio_content_external_id)

    episodes_to_trim.destroy_all

    return if audio_content_external_ids.empty?

    DeleteOrphanAudioContentJob.set(wait: ORPHAN_AUDIO_CONTENT_DELETE_DELAY).perform_later(audio_content_external_ids)
  end
end
