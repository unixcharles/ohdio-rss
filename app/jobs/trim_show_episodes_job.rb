class TrimShowEpisodesJob < ApplicationJob
  queue_as :default

  ORPHAN_MEDIA_DELETE_DELAY = 7.days

  def perform(show_id)
    show = Show.find_by(id: show_id)
    return if show.nil?

    episodes_to_trim = show.episodes.where("position > ?", Feed::MAX_MAX_EPISODES)
    return if episodes_to_trim.empty?

    media_ids = Segment.where(episode_id: episodes_to_trim.select(:id)).where.not(media_id: nil).distinct.pluck(:media_id)

    episodes_to_trim.destroy_all

    return if media_ids.empty?

    DeleteOrphanMediaJob.set(wait: ORPHAN_MEDIA_DELETE_DELAY).perform_later(media_ids)
  end
end
