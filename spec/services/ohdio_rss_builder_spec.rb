require "rails_helper"

RSpec.describe OhdioRssBuilder do
  let(:base_url) { "http://example.test" }

  it "builds emission_premiere RSS with merged mp3 enclosures and feed channel link" do
    segment_one = instance_double(Ohdio::Segment, duration: 30)
    segment_two = instance_double(Ohdio::Segment, duration: 60)
    episode = instance_double(
      Ohdio::Episode,
      id: "ep-2",
      title: "Episode Two",
      description: "Episode with segments",
      published_at: "2024-01-02T10:00:00Z",
      is_replay: false,
      url: "https://ici.radio-canada.ca/ohdio/balados/1/episode-two",
      segments: [ segment_one, segment_two ]
    )

    show = instance_double(
      Ohdio::Show,
      title: "My Show",
      description: "Show description",
      image_url: "https://images.example.com/{width}/cover_{ratio}.jpg",
      type: "emission_premiere",
      url: nil,
      episodes: [ episode ]
    )

    feed = instance_double(Feed, uid: "feed-uid", name: "Test Feed", exclude_replays: true, show: show)

    xml = described_class.new(feed: feed, base_url: base_url).generate

    expect(xml).to include("<link>#{base_url}/rss/feed-uid</link>")
    expect(xml).to include("#{base_url}/downloads/feed-uid/episodes/ep-2.mp3")
    expect(xml).to include('type="audio/mpeg"')
  end

  it "builds non-emission RSS items with direct audio URLs" do
    episode = instance_double(
      Ohdio::Episode,
      id: "ep-1",
      title: "Episode One",
      description: "Episode description",
      published_at: "2024-01-01T10:00:00Z",
      duration: 120,
      is_replay: false,
      url: "https://ici.radio-canada.ca/ohdio/balados/1/episode-one",
      audio_url: "https://cdn.example.com/episode-one.mp3"
    )

    show = instance_double(
      Ohdio::Show,
      title: "My Podcast",
      description: "Podcast description",
      image_url: nil,
      type: "balado",
      url: nil,
      episodes: [ episode ]
    )

    feed = instance_double(Feed, uid: "feed-uid", name: "Test Feed", exclude_replays: true, show: show)

    xml = described_class.new(feed: feed, base_url: base_url).generate

    expect(xml).to include("https://cdn.example.com/episode-one.mp3")
    expect(xml).to include('type="audio/mpeg"')
  end

  it "filters replay episodes when feed excludes replays" do
    replay_episode = instance_double(
      Ohdio::Episode,
      id: "ep-replay",
      title: "Replay Episode",
      description: "Replay",
      published_at: "2024-01-03T10:00:00Z",
      is_replay: true,
      url: "https://ici.radio-canada.ca/ohdio/balados/1/replay-episode",
      segments: [ instance_double(Ohdio::Segment, duration: 30) ]
    )

    show = instance_double(
      Ohdio::Show,
      title: "My Show",
      description: "Show description",
      image_url: nil,
      type: "emission_premiere",
      url: nil,
      episodes: [ replay_episode ]
    )

    feed = instance_double(Feed, uid: "feed-uid", name: "Test Feed", exclude_replays: true, show: show)

    xml = described_class.new(feed: feed, base_url: base_url).generate

    expect(xml).not_to include("Replay Episode")
  end
end
