require "rails_helper"

RSpec.describe DeleteOrphanAudioContentJob, type: :job do
  it "deletes only media rows that remain orphaned" do
    show = Show.create!(external_id: 987, title: "Show")
    episode = show.episodes.create!(ohdio_episode_id: "ep-1")

    kept_medium = AudioContent.create!(external_id: "kept")
    orphan_medium = AudioContent.create!(external_id: "orphan")

    episode.segments.create!(audio_content_external_id: kept_medium.external_id, position: 1)

    described_class.perform_now([ kept_medium.external_id, orphan_medium.external_id ])

    expect(AudioContent.exists?(external_id: "kept")).to be(true)
    expect(AudioContent.exists?(external_id: "orphan")).to be(false)
  end
end
