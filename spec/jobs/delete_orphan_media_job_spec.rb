require "rails_helper"

RSpec.describe DeleteOrphanMediaJob, type: :job do
  it "deletes only media rows that remain orphaned" do
    show = Show.create!(ohdio_id: 987, title: "Show")
    episode = show.episodes.create!(ohdio_episode_id: "ep-1", position: 1)

    kept_medium = Medium.create!(media_id: "kept")
    orphan_medium = Medium.create!(media_id: "orphan")

    episode.segments.create!(media_id: kept_medium.media_id, position: 1)

    described_class.perform_now([ kept_medium.media_id, orphan_medium.media_id ])

    expect(Medium.exists?(media_id: "kept")).to be(true)
    expect(Medium.exists?(media_id: "orphan")).to be(false)
  end
end
