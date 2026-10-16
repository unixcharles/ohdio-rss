require "rails_helper"

RSpec.describe "Changing a feed's show", type: :request do
  before do
    allow(FeedRefreshScheduler).to receive(:enqueue)
    allow(OhdioApiThrottle).to receive(:call)
  end

  let!(:feed) do
    Feed.create!(name: "Hébert", show_external_id: 1124, max_episodes: 50).tap do |feed|
      feed.feed_filters.create!(kind: "segment", keyword: "Chantal Hébert", include: true)
    end
  end

  it "renders the change show page" do
    get edit_feed_ohdio_show_path(feed)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("New show URL or ID")
  end

  it "points the feed at the new show and keeps its RSS uid, filters and settings" do
    allow(Ohdio::Fetcher).to receive(:fetch).with(2000)
      .and_return(Ohdio::Show.new(id: 2000, title: "Super Matin", type: "emission_premiere"))
    uid = feed.uid

    patch feed_ohdio_show_path(feed), params: { show_input: "https://ici.radio-canada.ca/ohdio/premiere/emissions/2000/super-matin" }

    expect(response).to redirect_to(feed_path(feed))
    follow_redirect!
    expect(response.body).to include("This feed now follows Super Matin")

    feed.reload
    expect(feed.show_external_id).to eq(2000)
    expect(feed.uid).to eq(uid)
    expect(feed.max_episodes).to eq(50)
    expect(feed.segment_filters.pluck(:keyword)).to eq([ "Chantal Hébert" ])
    expect(FeedRefreshScheduler).to have_received(:enqueue).with(2000, force: true)
  end

  it "shows an error and leaves the feed alone when the show is not found" do
    allow(Ohdio::Fetcher).to receive(:fetch).and_raise(Ohdio::UnknownTypeError, "nope")

    patch feed_ohdio_show_path(feed), params: { show_input: "99999" }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("No Ohdio show found with ID 99999")
    expect(feed.reload.show_external_id).to eq(1124)
  end

  it "does nothing when the show is unchanged" do
    allow(Ohdio::Fetcher).to receive(:fetch).with(1124)
      .and_return(Ohdio::Show.new(id: 1124, title: "Tout un matin", type: "emission_premiere"))

    expect do
      patch feed_ohdio_show_path(feed), params: { show_input: "1124" }
    end.not_to(change { feed.reload.updated_at })

    expect(response).to redirect_to(feed_path(feed))
    follow_redirect!
    expect(response.body).to include("This feed already follows Tout un matin")
  end
end
