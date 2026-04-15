require "rails_helper"
require "ostruct"

RSpec.describe OhdioEpisodeSegmentSyncService do
  before do
    allow(OhdioApiThrottle).to receive(:call)
    allow(ResolveAudioContentJob).to receive(:perform_later)
  end

  it "falls back to other pages when hint drifts" do
    show = Show.create!(
      external_id: 123,
      title: "Emission",
      ohdio_type: "emission_premiere",
      page_size: 2,
      total_episodes: 4
    )
    Feed.create!(name: "Feed", show_external_id: 123, max_episodes: 4)
    episode = show.episodes.create!(ohdio_episode_id: "ep-target")

    page_one = OpenStruct.new(episodes: [ OpenStruct.new(id: "ep-other", segments: []) ])
    segment = OpenStruct.new(title: "bloc politique", duration: 30, seek_time: 5, media_id: "m1")
    target_episode = OpenStruct.new(id: "ep-target", segments: [ segment ])
    page_two = OpenStruct.new(episodes: [ target_episode ])

    expect(Ohdio::Fetcher).to receive(:fetch).with(123, type: :emission_premiere, page: 1).ordered.and_return(page_one)
    expect(Ohdio::Fetcher).to receive(:fetch).with(123, type: :emission_premiere, page: 2).ordered.and_return(page_two)

    described_class.new(episode: episode, page_hint: 1).call

    episode.reload
    expect(episode.has_valid_segments).to be(true)
    expect(episode.segments.count).to eq(1)
    expect(episode.segments.first.audio_content_external_id).to eq("m1")
    expect(AudioContent.find_by(external_id: "m1")).to be_present
  end
end
