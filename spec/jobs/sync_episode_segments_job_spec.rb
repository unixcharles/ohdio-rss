require "rails_helper"

RSpec.describe SyncEpisodeSegmentsJob, type: :job do
  it "passes page hint and max episodes to sync service" do
    show = Show.create!(external_id: 123, title: "Show", ohdio_type: "emission_premiere")
    episode = show.episodes.create!(ohdio_episode_id: "ep-1")

    service = instance_double(OhdioEpisodeSegmentSyncService, call: true)

    expect(OhdioEpisodeSegmentSyncService).to receive(:new).with(
      episode: episode,
      page_hint: 3,
      max_episodes: 250
    ).and_return(service)

    described_class.perform_now(episode.id, 3, 250)
  end

  it "returns when episode is missing" do
    expect(OhdioEpisodeSegmentSyncService).not_to receive(:new)

    described_class.perform_now(-1, 1, 10)
  end
end
