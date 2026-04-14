class RssController < ApplicationController
  def show
    feed = Feed.find_by!(uid: params[:uid])
    FeedRefreshScheduler.enqueue(feed.show_id)
    rss_xml = OhdioRssBuilder.new(feed: feed, base_url: request.base_url).generate

    render plain: rss_xml, content_type: "application/xml"
  end
end
