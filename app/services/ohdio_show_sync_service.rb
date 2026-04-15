class OhdioShowSyncService
  def initialize(show_external_id:, type: nil, page: 1, max_episodes: nil)
    @show_external_id = show_external_id.to_i
    @type = type
    @page = page.to_i
    @max_episodes = normalize_max_episodes(max_episodes)
  end

  def call
    fetched_show = fetch_show
    show_record, show_metadata_changed = upsert_show(fetched_show)
    synced_episode_ids, synced_episodes_count = sync_episodes(show_record, fetched_show)
    deleted_episodes_count = prune_missing_episodes(show_record, fetched_show, synced_episode_ids)
    prune_episodes_beyond_limit(show_record)

    page_had_any_change = show_metadata_changed || synced_episodes_count.positive? || deleted_episodes_count.positive?

    [ show_record, fetched_show, { page_had_any_change: page_had_any_change } ]
  rescue StandardError => e
    mark_failure(e)
    raise
  end

  private

  def fetch_show
    OhdioApiThrottle.call

    if @type.present?
      Ohdio::Fetcher.fetch(@show_external_id, type: @type.to_sym, page: @page)
    else
      Ohdio::Fetcher.fetch(@show_external_id, page: @page)
    end
  end

  def upsert_show(fetched_show)
    show_record = Show.find_or_initialize_by(external_id: @show_external_id)
    show_metadata_changed = show_metadata_changed?(show_record, fetched_show)

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

    [ show_record, show_metadata_changed ]
  end

  def sync_episodes(show_record, fetched_show)
    current_page = fetched_show.page.to_i
    synced_count = 0

    fetched_show.episodes.filter_map do |episode|
      episode_record = show_record.episodes.find_or_initialize_by(ohdio_episode_id: episode.id.to_s)
      episode_record.assign_attributes(
        title: episode.title,
        description: episode.description,
        published_at: parse_time(episode.published_at),
        duration: episode.duration,
        is_replay: episode.is_replay,
        url: episode.url
      )

      if show_record.emission_premiere?
        episode_record.audio_url = nil
      else
        episode_record.audio_url = resolve_episode_audio_url(episode)
      end

      episode_changed = episode_record.new_record? || episode_record.changed?
      episode_record.save!
      synced_count += 1 if episode_changed
      enqueue_followup_jobs(show_record, episode_record, current_page)
      episode_record.ohdio_episode_id
    end.then { |synced_ids| [ synced_ids, synced_count ] }
  end

  def enqueue_followup_jobs(show_record, episode_record, page_hint)
    if show_record.emission_premiere?
      SyncEpisodeSegmentsJob.perform_later(episode_record.id, page_hint, @max_episodes)
    end
  end

  def prune_missing_episodes(show_record, fetched_show, synced_episode_ids)
    scope = episodes_for_page_window(show_record, fetched_show)
    if synced_episode_ids.empty?
      return scope.destroy_all.size
    end

    scope.where.not(ohdio_episode_id: synced_episode_ids).destroy_all.size
  end

  def episodes_for_page_window(show_record, fetched_show)
    page_size = fetched_show.page_size.to_i
    return show_record.episodes.none if page_size <= 0

    offset = [ @page - 1, 0 ].max * page_size
    ids_for_page = show_record.episodes.newest_first.offset(offset).limit(page_size).select(:id)
    show_record.episodes.where(id: ids_for_page)
  end

  def prune_episodes_beyond_limit(show_record)
    ids_to_keep = show_record.episodes.newest_first.limit(@max_episodes).select(:id)
    show_record.episodes.where.not(id: ids_to_keep).destroy_all
  end

  def resolve_episode_audio_url(episode)
    OhdioApiThrottle.call
    episode.audio_url
  rescue StandardError
    nil
  end

  def parse_time(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def mark_failure(error)
    show_record = Show.find_or_initialize_by(external_id: @show_external_id)
    show_record.assign_attributes(sync_status: "failed", sync_error: error.message)
    show_record.save(validate: false)
  end

  def normalize_max_episodes(value)
    parsed = value.to_i
    parsed = effective_max_episodes if parsed <= 0

    [ parsed, Feed::MAX_MAX_EPISODES ].min
  end

  def effective_max_episodes
    configured = Feed.where(show_external_id: @show_external_id).maximum(:max_episodes).to_i
    configured = Feed::DEFAULT_MAX_EPISODES if configured <= 0
    configured
  end

  def show_metadata_changed?(show_record, fetched_show)
    show_record.new_record? ||
      show_record.title != fetched_show.title ||
      show_record.description != fetched_show.description ||
      show_record.image_url != fetched_show.image_url ||
      show_record.ohdio_type != fetched_show.type ||
      show_record.page_size != fetched_show.page_size ||
      show_record.total_episodes != fetched_show.total_episodes ||
      show_record.url != fetched_show.url
  end
end
