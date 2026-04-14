class Feed < ApplicationRecord
  DEFAULT_MAX_EPISODES = 100
  MAX_MAX_EPISODES = 1000

  before_validation :ensure_uid, on: :create
  after_commit :enqueue_initial_sync, on: :create
  after_commit :enqueue_sync_on_show_change, on: :update

  has_one :show, class_name: "Show", foreign_key: :ohdio_id, primary_key: :show_id, inverse_of: :feeds

  validates :name, presence: true
  validates :show_id, presence: true, numericality: { only_integer: true }
  validates :uid, presence: true, uniqueness: true
  validates :max_episodes, presence: true,
                           numericality: {
                             only_integer: true,
                             greater_than: 0,
                             less_than_or_equal_to: MAX_MAX_EPISODES
                           }
  validates :episode_query, length: { maximum: 500 }
  validates :segment_query, length: { maximum: 500 }

  def self.search_ohdio(query, filter: :all)
    normalized_query = query.to_s.strip
    return [] if normalized_query.blank?

    Ohdio::Searcher.search(normalized_query, filter: filter)
  end

  def filtered_episodes(show: self.show)
    return Episode.none if show.nil?

    limited_ids = show.episodes.order(:position).limit(max_episodes).select(:id)
    scope = show.episodes.where(id: limited_ids).order(:position)
    scope = scope.where(is_replay: [ false, nil ]) if exclude_replays
    scope = EpisodeQueryFilter.apply(scope, episode_query)
    scope = scope.where(has_valid_segments: true) if show.emission_premiere?
    scope
  end

  def filtered_segments_for_episode(episode:)
    scope = episode.segments.includes(:medium).order(:position).where.not(media_id: nil)
    return scope if segment_query.blank?

    scope = scope.where("duration > 0")

    EpisodeQueryFilter.apply(scope, segment_query, columns: [ :title ])
  end

  def items
    show_record = show
    return [] if show_record.nil?

    if show_record.emission_premiere? && segment_query.present?
      segment_items(show_record)
    else
      episode_items(show_record)
    end
  end

  private

  def episode_items(show_record)
    filtered_episodes(show: show_record).filter_map do |episode|
      if show_record.emission_premiere?
        segments = filtered_segments_for_episode(episode: episode)
        next if segments.empty?
        next if segments.any? { |segment| segment.media_id.present? && (segment.medium.nil? || !segment.medium.resolved?) }
      else
        next if episode.audio_url.blank?
      end

      FeedItems::EpisodeItem.new(feed: self, show: show_record, episode: episode)
    end
  end

  def segment_items(show_record)
    filtered_episodes(show: show_record).flat_map do |episode|
      filtered_segments_for_episode(episode: episode).filter_map do |segment|
        next if segment.media_id.present? && (segment.medium.nil? || !segment.medium.resolved?)
        next if segment.medium&.audio_url.blank?

        FeedItems::SegmentItem.new(feed: self, episode: episode, segment: segment)
      end
    end
  end

  def ensure_uid
    self.uid ||= SecureRandom.hex(16)
  end

  def enqueue_initial_sync
    FeedRefreshScheduler.enqueue(show_id, force: true)
  end

  def enqueue_sync_on_show_change
    return unless saved_change_to_show_id?

    FeedRefreshScheduler.enqueue(show_id, force: true)
  end
end
