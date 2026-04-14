class FeedsController < ApplicationController
  PAGE_CACHE_TTL = 5.minutes
  MEDIA_URL_CACHE_TTL = 24.hours
  MEDIA_URL_THROTTLE_SECONDS = 1.0
  SEARCH_FILTERS = %w[all balado emission grande_serie audiobook].freeze

  before_action :set_feed, only: %i[show episodes segments edit update destroy]

  def index
    @feeds = Feed.order(created_at: :desc)
  end

  def show
    if bypass_page_cache?
      load_show_metadata
      return
    end

    html = Rails.cache.fetch(show_page_cache_key(@feed), expires_in: PAGE_CACHE_TTL) do
      load_show_metadata
      render_to_string(template: "feeds/show", layout: false)
    end

    render html: html.html_safe
  rescue Ohdio::Error => e
    @show_error = e.message
  end

  def episodes
    if bypass_page_cache?
      load_episodes
      return
    end

    html = Rails.cache.fetch(episodes_page_cache_key(@feed), expires_in: PAGE_CACHE_TTL) do
      load_episodes
      render_to_string(template: "feeds/episodes", layout: false)
    end

    render html: html.html_safe
  rescue Ohdio::Error => e
    @show_error = e.message
    @episodes = []
  end

  def segments
    if bypass_page_cache? || params[:resolve_media_id].present?
      load_segments
      return
    end

    episode_id = params[:episode_id].to_s
    html = Rails.cache.fetch(segments_page_cache_key(@feed, episode_id), expires_in: PAGE_CACHE_TTL) do
      load_segments
      render_to_string(template: "feeds/segments", layout: false)
    end

    render html: html.html_safe
  rescue Ohdio::Error => e
    @show_error = e.message
    @episode = nil
    @segments = []
    render :segments
  end

  def new
    @exclude_replays = params.key?(:exclude_replays) ? params[:exclude_replays] == "1" : true
    @feed = Feed.new(exclude_replays: @exclude_replays)
    @query = params[:query].to_s.strip
    @filter = SEARCH_FILTERS.include?(params[:filter]) ? params[:filter] : "all"
    @results = []

    return if @query.blank?

    @results = Feed.search_ohdio(@query, filter: @filter.to_sym).select { |result| result.is_a?(Ohdio::Show) }
  rescue Ohdio::Error => e
    flash.now[:alert] = "Search failed: #{e.message}"
  end

  def edit; end

  def create
    @feed = Feed.new(feed_params)

    if @feed.save
      redirect_to @feed, notice: "Feed was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @feed.update(feed_params)
      redirect_to @feed, notice: "Feed was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @feed.destroy!
    redirect_to feeds_path, notice: "Feed was successfully deleted."
  end

  private

  def set_feed
    @feed = Feed.find(params[:id])
  end

  def feed_params
    params.expect(feed: %i[name show_id exclude_replays])
  end

  def replay_excluded?(feed, episode)
    feed.exclude_replays && episode.is_replay
  end

  def load_show_metadata
    @show = @feed.show
    @show_metadata = {
      title: @show.title,
      description: @show.description,
      image_url: @show.image_url,
      type: @show.type,
      page: @show.page,
      page_size: @show.page_size,
      total_episodes: @show.total_episodes,
      url: @show.url
    }
  end

  def load_episodes
    @show = @feed.show
    @episodes = @show.episodes.first(5)
  end

  def load_segments
    @show = @feed.show
    @episode = @show.episodes.find { |item| item.id.to_s == params[:episode_id].to_s }
    raise ActiveRecord::RecordNotFound if @episode.nil?
    raise ActiveRecord::RecordNotFound if replay_excluded?(@feed, @episode)

    @segments = @episode.segments

    resolve_media_id = params[:resolve_media_id].to_s
    return if resolve_media_id.blank?

    segment = @segments.find { |item| item.media_id.to_s == resolve_media_id }
    return if segment.nil?

    segment_audio_url(segment)
  end

  def bypass_page_cache?
    flash[:notice].present? || flash[:alert].present?
  end

  def show_page_cache_key(feed)
    [ "feed-show-page-v1", feed.id, feed.updated_at.to_i, request.base_url ]
  end

  def episodes_page_cache_key(feed)
    [ "feed-episodes-page-v1", feed.id, feed.updated_at.to_i, request.base_url ]
  end

  def segments_page_cache_key(feed, episode_id)
    [ "feed-segments-page-v3", feed.id, episode_id.to_s, feed.updated_at.to_i, request.base_url ]
  end

  def segment_audio_url(segment)
    media_id = segment.media_id

    if media_id.present?
      Rails.cache.fetch([ "media-url", media_id ], expires_in: MEDIA_URL_CACHE_TTL) do
        sleep(MEDIA_URL_THROTTLE_SECONDS)
        segment.audio_url
      end
    else
      segment.audio_url
    end
  end
end
