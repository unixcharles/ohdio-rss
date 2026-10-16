require "rails_helper"

RSpec.describe FeedItems::SegmentItem do
  let(:show) { Show.create!(external_id: 893, title: "Tout un matin", ohdio_type: "emission_premiere") }
  let(:feed) { Feed.create!(name: "McSween", show_external_id: 893) }
  let(:episode) { show.episodes.create!(ohdio_episode_id: "ep-1", url: "https://ici.radio-canada.ca/ohdio/episode") }

  before { allow(FeedRefreshScheduler).to receive(:enqueue) }

  it "links to the segment's own Ohdio page" do
    segment = episode.segments.create!(title: "Chronique", position: 1,
                                       share_url: "https://ici.radio-canada.ca/ohdio/segment/2503344/chronique-economique-pierre-yves-mcsween")

    expect(described_class.new(feed: feed, episode: episode, segment: segment).link).to eq(segment.share_url)
  end

  it "falls back to the episode page for segments synced before share URLs were stored" do
    segment = episode.segments.create!(title: "Chronique", position: 1)

    expect(described_class.new(feed: feed, episode: episode, segment: segment).link).to eq(episode.url)
  end
end
