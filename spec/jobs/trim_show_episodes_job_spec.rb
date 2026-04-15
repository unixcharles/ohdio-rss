require "rails_helper"

RSpec.describe TrimShowEpisodesJob, type: :job do
  before do
    clear_enqueued_jobs
  end

  it "removes episodes beyond the newest limit and their segments" do
    stub_const("Feed::MAX_MAX_EPISODES", 1)

    show = Show.create!(external_id: 123, title: "Show")
    keep_episode = show.episodes.create!(ohdio_episode_id: "ep-new", published_at: Time.zone.parse("2024-01-02 10:00:00"))
    trim_episode = show.episodes.create!(ohdio_episode_id: "ep-old", published_at: Time.zone.parse("2024-01-01 10:00:00"))

    keep_episode.segments.create!(audio_content_external_id: "keep-media", position: 1)
    trim_episode.segments.create!(audio_content_external_id: "trim-media", position: 1)

    described_class.perform_now(show.id)

    expect(show.episodes.exists?(id: keep_episode.id)).to be(true)
    expect(show.episodes.exists?(id: trim_episode.id)).to be(false)
    expect(Segment.where(episode_id: trim_episode.id)).to be_empty
    orphan_job = enqueued_jobs.find { |job| job[:job] == DeleteOrphanAudioContentJob }
    expect(orphan_job).to be_present
    expect(orphan_job[:at]).to be_present
    expect(orphan_job[:at]).to be_within(5.seconds).of(7.days.from_now.to_f)
  end

  it "enqueues orphan media deletion for trimmed segments" do
    stub_const("Feed::MAX_MAX_EPISODES", 1)

    show = Show.create!(external_id: 456, title: "Show")
    keep_episode = show.episodes.create!(ohdio_episode_id: "ep-1", published_at: Time.zone.parse("2024-01-02 10:00:00"))
    trim_episode = show.episodes.create!(ohdio_episode_id: "ep-2", published_at: Time.zone.parse("2024-01-01 10:00:00"))

    shared_medium = AudioContent.create!(external_id: "shared")
    orphan_medium = AudioContent.create!(external_id: "orphan")

    keep_episode.segments.create!(audio_content_external_id: shared_medium.external_id, position: 1)
    trim_episode.segments.create!(audio_content_external_id: shared_medium.external_id, position: 1)
    trim_episode.segments.create!(audio_content_external_id: orphan_medium.external_id, position: 2)

    described_class.perform_now(show.id)

    orphan_job = enqueued_jobs.find { |job| job[:job] == DeleteOrphanAudioContentJob }
    expect(orphan_job).to be_present
    expect(orphan_job[:args]).to include(match_array([ "shared", "orphan" ]))
  end
end
