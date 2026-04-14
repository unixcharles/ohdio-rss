class OhdioShowSyncService
  def initialize(show_id:, type: nil, page: 1, max_episodes: nil)
    @show_id = show_id.to_i
    @type = type
    @page = page.to_i
    @max_episodes = normalize_max_episodes(max_episodes)
  end

  def call
    fetched_show = fetch_show
    show_record = upsert_show(fetched_show)
    synced_episode_ids = sync_episodes(show_record, fetched_show)
    prune_missing_episodes(show_record, synced_episode_ids)
    prune_episodes_beyond_limit(show_record)

    [ show_record, fetched_show ]
  rescue StandardError => e
    mark_failure(e)
    raise
  end

  private

  def fetch_show
    OhdioApiThrottle.call

    if @type.present?
      Ohdio::Fetcher.fetch(@show_id, type: @type.to_sym, page: @page)
    else
      Ohdio::Fetcher.fetch(@show_id, page: @page)
    end
  end

  def upsert_show(fetched_show)
    show_record = Show.find_or_initialize_by(ohdio_id: @show_id)
    show_record.assign_attributes(
      title: fetched_show.title,
      description: fetched_show.description,
      image_url: fetched_show.image_url,
      ohdio_type: fetched_show.type,
      page_size: fetched_show.page_size,
      total_episodes: fetched_show.total_episodes,
      url: fetched_show.url,
      sync_status: "synced",
      sync_error: nil,
      last_synced_at: Time.current
    )
    show_record.save!
    show_record
  end

  def sync_episodes(show_record, fetched_show)
    page_size = fetched_show.page_size.to_i
    current_page = fetched_show.page.to_i

    fetched_show.episodes.each_with_index.filter_map do |episode, index|
      position = position_for(page: current_page, index: index, page_size: page_size)
      next if position > @max_episodes

      episode_record = show_record.episodes.find_or_initialize_by(ohdio_episode_id: episode.id.to_s)
      episode_record.assign_attributes(
        title: episode.title,
        description: episode.description,
        published_at: parse_time(episode.published_at),
        duration: episode.duration,
        is_replay: episode.is_replay,
        url: episode.url,
        page_number: current_page,
        position: position
      )

      if show_record.emission_premiere?
        episode_record.audio_url = nil
      else
        episode_record.audio_url = resolve_episode_audio_url(episode)
      end

      episode_record.save!
      enqueue_followup_jobs(show_record, episode_record)
      episode_record.ohdio_episode_id
    end
  end

  def enqueue_followup_jobs(show_record, episode_record)
    if show_record.emission_premiere?
      SyncEpisodeSegmentsJob.perform_later(episode_record.id)
    end
  end

  def prune_missing_episodes(show_record, synced_episode_ids)
    scope = show_record.episodes.where(page_number: @page)
    if synced_episode_ids.empty?
      scope.destroy_all
      return
    end

    scope.where.not(ohdio_episode_id: synced_episode_ids).destroy_all
  end

  def prune_episodes_beyond_limit(show_record)
    show_record.episodes.where("position > ?", @max_episodes).destroy_all
  end

  def resolve_episode_audio_url(episode)
    OhdioApiThrottle.call
    episode.audio_url
  rescue StandardError
    nil
  end

  def position_for(page:, index:, page_size:)
    return index + 1 if page_size <= 0

    ((page - 1) * page_size) + index + 1
  end

  def parse_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def mark_failure(error)
    show_record = Show.find_or_initialize_by(ohdio_id: @show_id)
    show_record.assign_attributes(sync_status: "failed", sync_error: error.message)
    show_record.save(validate: false)
  end

  def normalize_max_episodes(value)
    parsed = value.to_i
    parsed = effective_max_episodes if parsed <= 0

    [ parsed, Feed::MAX_MAX_EPISODES ].min
  end

  def effective_max_episodes
    configured = Feed.where(show_id: @show_id).maximum(:max_episodes).to_i
    configured = Feed::DEFAULT_MAX_EPISODES if configured <= 0
    configured
  end
end
