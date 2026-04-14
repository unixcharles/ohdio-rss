class OhdioRssBuilder
  def initialize(feed:, base_url:)
    @feed = feed
    @base_url = base_url
  end

  def generate
    show = @feed.show

    ApplicationController.render(
      template: "feeds/show",
      formats: [ :rss ],
      layout: false,
      assigns: {
        feed: @feed,
        show: show,
        rss_items: build_rss_items(show),
        base_url: @base_url,
        channel_link: rss_feed_url
      }
    )
  end

  private

  def build_rss_items(show)
    if show.type == "emission_premiere"
      show.episodes.filter_map do |episode|
        next if replay_excluded?(episode)

        segments = episode.segments
        next if segments.empty?

        {
          title: episode.title,
          description: episode.description,
          published_at: episode.published_at,
          duration: segments.sum { |segment| segment.duration.to_i },
          guid: episode.url || "ohdio-episode-#{episode.id}",
          link: episode.url,
          enclosure_url: episode_download_url(episode.id),
          enclosure_type: "audio/mpeg"
        }
      end
    else
      show.episodes.filter_map do |episode|
        next if replay_excluded?(episode)

        audio_url = episode.audio_url
        next if audio_url.blank?

        {
          title: episode.title,
          description: episode.description,
          published_at: episode.published_at,
          duration: episode.duration,
          guid: episode.url || "ohdio-episode-#{episode.id}",
          link: episode.url,
          enclosure_url: audio_url,
          enclosure_type: "audio/mpeg"
        }
      end
    end
  end

  def replay_excluded?(episode)
    @feed.exclude_replays && episode.is_replay
  end

  def rss_feed_url
    "#{@base_url}#{Rails.application.routes.url_helpers.rss_feed_path(uid: @feed.uid, format: :rss)}"
  end

  def episode_download_url(episode_id)
    "#{@base_url}#{Rails.application.routes.url_helpers.episode_download_mp3_path(uid: @feed.uid, episode_id: episode_id)}"
  end
end
