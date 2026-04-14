require "rails_helper"

RSpec.describe TrimShowEpisodesJob, type: :job do
  before do
    clear_enqueued_jobs
  end

  it "removes episodes over 1000 and their segments" do
    show = Show.create!(ohdio_id: 123, title: "Show")
    keep_episode = show.episodes.create!(ohdio_episode_id: "ep-1000", position: 1000)
    trim_episode = show.episodes.create!(ohdio_episode_id: "ep-1001", position: 1001)

    keep_episode.segments.create!(media_id: "keep-media", position: 1)
    trim_episode.segments.create!(media_id: "trim-media", position: 1)

    described_class.perform_now(show.id)

    expect(show.episodes.exists?(id: keep_episode.id)).to be(true)
    expect(show.episodes.exists?(id: trim_episode.id)).to be(false)
    expect(Segment.where(episode_id: trim_episode.id)).to be_empty
    orphan_job = enqueued_jobs.find { |job| job[:job] == DeleteOrphanMediaJob }
    expect(orphan_job).to be_present
    expect(orphan_job[:at]).to be_present
    expect(orphan_job[:at]).to be_within(5.seconds).of(7.days.from_now.to_f)
  end

  it "enqueues orphan media deletion for trimmed segments" do
    show = Show.create!(ohdio_id: 456, title: "Show")
    keep_episode = show.episodes.create!(ohdio_episode_id: "ep-1", position: 1)
    trim_episode = show.episodes.create!(ohdio_episode_id: "ep-2", position: 1001)

    shared_medium = Medium.create!(media_id: "shared")
    orphan_medium = Medium.create!(media_id: "orphan")

    keep_episode.segments.create!(media_id: shared_medium.media_id, position: 1)
    trim_episode.segments.create!(media_id: shared_medium.media_id, position: 1)
    trim_episode.segments.create!(media_id: orphan_medium.media_id, position: 2)

    described_class.perform_now(show.id)

    orphan_job = enqueued_jobs.find { |job| job[:job] == DeleteOrphanMediaJob }
    expect(orphan_job).to be_present
    expect(orphan_job[:args]).to include(match_array([ "shared", "orphan" ]))
  end
end
