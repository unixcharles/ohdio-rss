module FeedItems
  class EpisodeItem < BaseItem
    attr_reader :episode, :show

    def initialize(feed:, show:, episode:)
      super(feed: feed)
      @show = show
      @episode = episode
    end

    def episode?
      true
    end

    def title
      ApplicationController.helpers.display_episode_title(episode.title)
    end

    def description
      episode.description
    end

    def published_at
      episode.published_at
    end

    def duration
      episode.duration
    end

    def link
      episode.url
    end

    def guid
      episode.url.presence || "ohdio-episode-#{episode.ohdio_episode_id}"
    end

    def download_url(base_url:)
      if show.emission_premiere?
        "#{base_url}#{Rails.application.routes.url_helpers.episode_download_mp3_path(uid: feed.uid, episode_id: episode.ohdio_episode_id)}"
      else
        episode.audio_url.to_s
      end
    end

    def segment_link_path
      Rails.application.routes.url_helpers.episode_segments_feed_path(feed, episode_id: episode.ohdio_episode_id)
    end

    def show_segments_link?
      show.emission_premiere? && feed.segment_query.blank?
    end
  end
end
