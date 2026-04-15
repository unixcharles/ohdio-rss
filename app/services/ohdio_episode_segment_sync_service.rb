class OhdioEpisodeSegmentSyncService
  def initialize(episode:, page_hint: nil, max_episodes: nil)
    @episode = episode
    @show = episode.show
    @page_hint = normalize_page(page_hint)
    @max_episodes = max_episodes.to_i
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
    pages_to_check.each do |page|
      fetched_episode = fetch_episode_on_page(page)
      return fetched_episode unless fetched_episode.nil?
    end

    nil
  end

  def sync_segment(segment, index)
    external_id = segment.media_id.to_s.presence
    ensure_audio_content(external_id)

    segment_record = @episode.segments.find_or_initialize_by(position: index + 1)
    segment_record.assign_attributes(
      title: TextEntityNormalizer.call(segment.title),
      duration: segment.duration,
      seek_time: segment.seek_time,
      audio_content_external_id: external_id
    )
    segment_record.save!
    segment_record.id
  end

  def ensure_audio_content(external_id)
    return if external_id.blank?

    audio_content = AudioContent.find_or_create_by!(external_id: external_id)
    ResolveAudioContentJob.perform_later(audio_content.id) unless audio_content.resolved?
  end

  def valid_segments_scope(scope)
    scope.where.not(audio_content_external_id: nil)
  end

  def fetch_episode_on_page(page)
    OhdioApiThrottle.call
    fetched_show = Ohdio::Fetcher.fetch(@show.external_id, type: @show.ohdio_type.to_sym, page: page)
    fetched_show.episodes.find { |item| item.id.to_s == @episode.ohdio_episode_id.to_s }
  end

  def pages_to_check
    candidate_pages = bounded_pages
    return candidate_pages if @page_hint.nil?

    [ @page_hint, *candidate_pages.reject { |page| page == @page_hint } ]
  end

  def bounded_pages
    page_size = @show.page_size.to_i
    return [ 1 ] if page_size <= 0

    episodes_limit = effective_max_episodes
    return [ 1 ] if episodes_limit <= 0

    pages = (episodes_limit.to_f / page_size).ceil
    pages = [ pages, total_pages_for_show(page_size) ].min
    pages = 1 if pages <= 0
    (1..pages).to_a
  end

  def total_pages_for_show(page_size)
    total_episodes = @show.total_episodes.to_i
    return Float::INFINITY if total_episodes <= 0

    (total_episodes.to_f / page_size).ceil
  end

  def effective_max_episodes
    return @max_episodes if @max_episodes.positive?

    configured = Feed.where(show_external_id: @show.external_id).maximum(:max_episodes).to_i
    configured = Feed::DEFAULT_MAX_EPISODES if configured <= 0
    [ configured, Feed::MAX_MAX_EPISODES ].min
  end

  def normalize_page(value)
    page = value.to_i
    return nil if page <= 0

    page
  end
end
