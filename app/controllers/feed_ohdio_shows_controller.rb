# Points an existing feed at a different Ohdio show (e.g. after a show is replaced by a new one)
# while keeping its RSS URL, filters and settings, so podcast apps don't need to re-subscribe.
class FeedOhdioShowsController < ApplicationController
  before_action :set_feed

  def edit
    @show_input = @feed.show&.url || @feed.show_external_id.to_s
  end

  def update
    @show_input = params[:show_input].to_s
    fetched_show = OhdioShowLocator.call(@show_input)

    if fetched_show.id.to_i == @feed.show_external_id
      redirect_to @feed, notice: "This feed already follows #{fetched_show.title}."
      return
    end

    # Feed#enqueue_sync_on_show_change forces a sync of the new show.
    @feed.update!(show_external_id: fetched_show.id)
    redirect_to @feed, notice: "This feed now follows #{fetched_show.title}. Its episodes are syncing; the RSS URL is unchanged."
  rescue OhdioShowLocator::Error => e
    @error = e.message
    render :edit, status: :unprocessable_entity
  end

  private

  def set_feed
    @feed = Feed.find(params[:feed_id])
  end
end
