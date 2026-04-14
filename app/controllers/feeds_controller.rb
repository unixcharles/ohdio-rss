class FeedsController < ApplicationController
  SEARCH_FILTERS = %w[all balado emission grande_serie audiobook].freeze

  before_action :set_feed, only: %i[show episodes segments destroy]
  before_action :enqueue_feed_refresh, only: %i[show episodes segments]

  def index
    @feeds = Feed.order(created_at: :desc)
  end

  def show
    load_show_metadata
  end

  def episodes
    load_episodes
  end

  def segments
    load_segments
  end

  def new
    @exclude_replays = params.key?(:exclude_replays) ? params[:exclude_replays] == "1" : true
    @max_episodes = max_episodes_from_params
    @episode_query = params[:episode_query].to_s.strip
    @segment_query = params[:segment_query].to_s.strip
    @show_id = params[:show_id].to_s.strip
    @name = params[:name].to_s.strip
    @feed = Feed.new(
      name: @name,
      show_id: @show_id,
      exclude_replays: @exclude_replays,
      max_episodes: @max_episodes,
      episode_query: @episode_query,
      segment_query: @segment_query
    )
  end

  def create
    @feed = Feed.new(feed_params)

    if @feed.save
      redirect_to @feed, notice: "Feed was successfully created."
    else
      render :new, status: :unprocessable_entity
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
    params.expect(feed: %i[name show_id exclude_replays max_episodes episode_query segment_query])
  end

  def load_show_metadata
    @show = @feed.show
    return if @show.nil?

    @first_item = @feed.items.first

    @show_metadata = {
      title: @show.title,
      description: @show.description,
      image_url: @show.image_url,
      type: @show.ohdio_type,
      url: @show.url
    }
  end

  def load_episodes
    @show = @feed.show
    if @show.nil?
      @items = []
      return
    end

    all_items = @feed.items
    if all_items.empty?
      @items = []
      @pagy = nil
      return
    end

    @pagy = Pagy::Offset.new(count: all_items.size, page: [ params[:page].to_i, 1 ].max, limit: 20)
    @items = all_items[@pagy.offset, @pagy.limit] || []
  end

  def load_segments
    @show = @feed.show
    raise ActiveRecord::RecordNotFound if @show.nil?

    @episode = @feed.filtered_episodes(show: @show).find_by!(ohdio_episode_id: params[:episode_id].to_s)

    @segments = @episode.segments.includes(:medium).order(:position)
  end

  def max_episodes_from_params
    value = params[:max_episodes].to_i
    return Feed::DEFAULT_MAX_EPISODES if value <= 0

    [ value, Feed::MAX_MAX_EPISODES ].min
  end

  def enqueue_feed_refresh
    FeedRefreshScheduler.enqueue(@feed.show_id)
  end
end
