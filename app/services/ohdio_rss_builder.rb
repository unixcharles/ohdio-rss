class OhdioRssBuilder
  include ApplicationHelper

  def initialize(feed:, base_url:)
    @feed = feed
    @base_url = base_url
  end

  def generate
    show = @feed.show
    raise ActiveRecord::RecordNotFound if show.nil?

    ApplicationController.render(
      template: "feeds/show",
      formats: [ :rss ],
      layout: false,
      assigns: {
        feed: @feed,
        show: show,
          rss_items: build_rss_items,
        base_url: @base_url,
        channel_link: rss_feed_url
      }
    )
  end

  private

  def build_rss_items
    @feed.items.map do |item|
      {
        title: item.title,
        description: item.description,
        published_at: item.published_at,
        duration: item.duration,
        guid: item.guid,
        link: item.link,
        enclosure_url: item.download_url(base_url: @base_url),
        enclosure_type: "audio/mpeg"
      }
    end
  end

  def rss_feed_url
    "#{@base_url}#{Rails.application.routes.url_helpers.rss_feed_path(uid: @feed.uid, format: :rss)}"
  end
end
