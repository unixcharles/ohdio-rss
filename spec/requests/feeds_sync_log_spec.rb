require "rails_helper"

RSpec.describe "Feed sync log", type: :request do
  before { allow(FeedRefreshScheduler).to receive(:enqueue) }

  let(:show) { Show.create!(external_id: 987, title: "Tout un matin", ohdio_type: "emission_premiere") }
  let(:feed) { Feed.create!(name: "Hébert", show_external_id: show.external_id) }

  it "alerts on the feed page when the show had recent sync problems" do
    ShowSyncError.record!(show, kind: "sync_failed", message: "Page 1: Ohdio::ApiError: PersistedQueryNotFound")

    get feed_path(feed)

    expect(response.body).to include("1 sync problem in the last 24 hours")
    expect(response.body).to include(sync_log_feed_path(feed))
  end

  it "does not alert for old problems" do
    travel_to(2.days.ago) { ShowSyncError.record!(show, kind: "sync_failed", message: "old") }

    get feed_path(feed)

    expect(response.body).not_to include("sync problem")
  end

  it "lists the show's sync errors" do
    ShowSyncError.record!(show, kind: "segments_failed", message: "Ohdio::ApiError: PersistedQueryNotFound")

    get sync_log_feed_path(feed)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Segments failed")
    expect(response.body).to include("PersistedQueryNotFound")
  end
end
