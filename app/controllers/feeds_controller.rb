class FeedsController < ApplicationController
  SEARCH_FILTERS = %w[all balado emission grande_serie audiobook].freeze
  FILTER_KINDS = %w[episode segment].freeze

  before_action :set_feed, only: %i[show episodes segments edit update destroy]
  before_action :enqueue_feed_refresh, only: %i[show episodes segments edit]

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
    @show_external_id = params[:show_external_id].to_s.strip
    @name = normalized_feed_name_from_params
    @feed = Feed.new(
      name: @name,
      show_external_id: @show_external_id,
      exclude_replays: @exclude_replays,
      max_episodes: @max_episodes
    )
    load_filter_rows_from_feed
  end

  def edit
    load_filter_rows_from_feed
  end

  def create
    @feed = Feed.new
    process_form
  end

  def update
    process_form
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
    params.expect(feed: %i[name show_external_id exclude_replays max_episodes])
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
      url: @show.url,
      chronological_order: @show.chronological_order?
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

    @segments = @episode.segments.includes(:audio_content).order(:position)
  end

  def max_episodes_from_params
    value = params[:max_episodes].to_i
    return Feed::DEFAULT_MAX_EPISODES if value <= 0

    [ value, Feed::MAX_MAX_EPISODES ].min
  end

  def normalized_feed_name_from_params
    helpers.display_episode_title(params[:name].to_s).strip
  end

  def enqueue_feed_refresh
    FeedRefreshScheduler.enqueue(@feed.show_external_id)
  end

  # --- Filter row handling (new/create/edit/update) -----------------------
  #
  # Filter rows are held as plain hashes (keyword:, include:) for the whole add/remove/preview/
  # save round trip - see FeedFilterReplacer for why they only become real FeedFilter records at
  # save time.

  def process_form
    @feed.assign_attributes(feed_params)
    load_filter_rows_from_params
    apply_row_actions

    case form_action
    when :save
      save_feed
    when :preview
      build_preview
      render_form
    else
      render_form
    end
  end

  def form_action
    return :add_episode if params[:add_episode_filter]
    return :remove_episode if params[:remove_episode_filter]
    return :add_segment if params[:add_segment_filter]
    return :remove_segment if params[:remove_segment_filter]
    return :preview if params[:commit] == "Preview"

    :save
  end

  def load_filter_rows_from_feed
    @episode_filter_rows = rows_from_association(@feed.episode_filters)
    @segment_filter_rows = rows_from_association(@feed.segment_filters)
  end

  def load_filter_rows_from_params
    @episode_filter_rows = rows_from_params(:episode) || rows_from_association(@feed.episode_filters)
    @segment_filter_rows = rows_from_params(:segment) || rows_from_association(@feed.segment_filters)
  end

  def rows_from_association(filters)
    rows = filters.map { |filter| { keyword: filter.keyword, include: filter.include? } }
    rows.presence || [ blank_row ]
  end

  def rows_from_params(kind)
    keyword_param = params[:"#{kind}_filter_keyword"]
    return nil if keyword_param.nil?

    include_param = Array(params[:"#{kind}_filter_include"])
    Array(keyword_param).each_with_index.map do |keyword, index|
      { keyword: keyword.to_s, include: include_param[index] != "false" }
    end.presence || [ blank_row ]
  end

  def blank_row
    { keyword: "", include: true }
  end

  def apply_row_actions
    @episode_filter_rows = apply_row_action(@episode_filter_rows, :episode)
    @segment_filter_rows = apply_row_action(@segment_filter_rows, :segment)
  end

  def apply_row_action(rows, kind)
    if params[:"add_#{kind}_filter"]
      rows + [ blank_row ]
    elsif (remove_index = params[:"remove_#{kind}_filter"])
      remaining = rows.each_with_index.reject { |_row, index| index == remove_index.to_i }.map(&:first)
      remaining.presence || [ blank_row ]
    else
      rows
    end
  end

  def save_feed
    Feed.transaction do
      @feed.save!
      FeedFilterReplacer.call(feed: @feed, kind: "episode", rows: @episode_filter_rows)
      FeedFilterReplacer.call(feed: @feed, kind: "segment", rows: @segment_filter_rows)
    end
    redirect_to @feed, notice: "Feed was successfully #{action_name == 'create' ? 'created' : 'updated'}."
  rescue ActiveRecord::RecordInvalid => e
    @feed.errors.merge!(e.record.errors) unless e.record.equal?(@feed)
    render_form(status: :unprocessable_entity)
  end

  def build_preview
    @show = @feed.show
    return if @show.nil?

    preview_feed = Feed.new(@feed.attributes.slice("show_external_id", "max_episodes", "exclude_replays"))
    preview_feed.episode_filters = @episode_filter_rows.map { |row| build_preview_filter("episode", row) }
    preview_feed.segment_filters = @segment_filter_rows.map { |row| build_preview_filter("segment", row) }

    @preview_episodes = preview_feed.filtered_episodes(show: @show).to_a

    return unless @show.emission_premiere?

    @preview_segments_by_episode = @preview_episodes.each_with_object({}) do |episode, hash|
      hash[episode] = preview_feed.filtered_segments_for_episode(episode: episode).to_a
    end
  end

  def build_preview_filter(kind, row)
    FeedFilter.new(kind: kind, keyword: row[:keyword], include: row[:include])
  end

  def render_form(status: :ok)
    @show_external_id = @feed.show_external_id.to_s
    render(action_name == "update" ? :edit : :new, status: status)
  end
end
