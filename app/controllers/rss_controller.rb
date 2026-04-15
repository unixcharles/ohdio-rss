class RssController < ApplicationController
  def show
    feed = Feed.find_by!(uid: params[:uid])
    FeedRefreshScheduler.enqueue(feed.show_external_id)
    rss_xml = OhdioRssBuilder.new(feed: feed, base_url: resolved_base_url).generate

    render plain: rss_xml, content_type: "application/xml"
  end

  private

  def resolved_base_url
    configured = ENV["PUBLIC_BASE_URL"].to_s.strip
    return request.base_url if configured.blank?

    configured.chomp("/")
  end
end
