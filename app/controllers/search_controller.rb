class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @filter = FeedsController::SEARCH_FILTERS.include?(params[:filter]) ? params[:filter] : "all"
    @results = []

    return if @query.blank?

    @results = Feed.search_ohdio(@query, filter: @filter.to_sym).select { |result| result.is_a?(Ohdio::Show) }
  rescue Ohdio::Error => e
    flash.now[:alert] = "Search failed: #{e.message}"
  end
end
