module FeedItems
  class SegmentItem < BaseItem
    attr_reader :episode, :segment

    def initialize(feed:, episode:, segment:)
      super(feed: feed)
      @episode = episode
      @segment = segment
    end

    def segment?
      true
    end

    def title
      TextEntityNormalizer.call(segment.title)
    end

    def description
      nil
    end

    def published_at
      episode.published_at
    end

    def duration
      segment.duration
    end

    def link
      episode.url
    end

    def guid
      "ohdio-segment-#{segment.id}"
    end

    def download_url(base_url:)
      "#{base_url}#{Rails.application.routes.url_helpers.segment_download_mp3_path(uid: feed.uid, segment_id: segment.id)}"
    end
  end
end
