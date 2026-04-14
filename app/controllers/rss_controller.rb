class RssController < ApplicationController
  RSS_CACHE_TTL = 5.minutes

  def show
    feed = Feed.find_by!(uid: params[:uid])
    rss_xml = Rails.cache.fetch(rss_cache_key(feed), expires_in: RSS_CACHE_TTL) do
      OhdioRssBuilder.new(feed: feed, base_url: request.base_url).generate
    end

    render plain: rss_xml, content_type: "application/xml"
  end

  private

  def rss_cache_key(feed)
    [ "rss-feed", feed.uid, feed.show_id, feed.updated_at.to_i, request.base_url ]
  end
end
