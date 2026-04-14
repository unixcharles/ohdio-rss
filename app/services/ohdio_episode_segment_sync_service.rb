class OhdioEpisodeSegmentSyncService
  def initialize(episode:)
    @episode = episode
    @show = episode.show
  end

  def call
    return unless @show.emission_premiere?

    fetched_episode = fetch_episode
    return if fetched_episode.nil?

    synced_ids = fetched_episode.segments.each_with_index.map do |segment, index|
      sync_segment(segment, index)
    end

    @episode.segments.where.not(id: synced_ids.compact).destroy_all
    @episode.update!(has_valid_segments: valid_segments_scope(@episode.segments).exists?)
  end

  private

  def fetch_episode
    OhdioApiThrottle.call
    fetched_show = Ohdio::Fetcher.fetch(@show.ohdio_id, type: @show.ohdio_type.to_sym, page: @episode.page_number || 1)
    fetched_show.episodes.find { |item| item.id.to_s == @episode.ohdio_episode_id.to_s }
  end

  def sync_segment(segment, index)
    media_id = segment.media_id.to_s.presence
    ensure_medium(media_id)

    segment_record = @episode.segments.find_or_initialize_by(position: index + 1)
    segment_record.assign_attributes(
      title: TextEntityNormalizer.call(segment.title),
      duration: segment.duration,
      seek_time: segment.seek_time,
      media_id: media_id
    )
    segment_record.save!
    segment_record.id
  end

  def ensure_medium(media_id)
    return if media_id.blank?

    medium = Medium.find_or_create_by!(media_id: media_id)
    ResolveMediaJob.perform_later(medium.id) unless medium.resolved?
  end

  def valid_segments_scope(scope)
    scope.where.not(media_id: nil)
  end
end
