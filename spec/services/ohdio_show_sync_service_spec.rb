require "rails_helper"
require "ostruct"

RSpec.describe OhdioShowSyncService do
  before do
    allow(OhdioApiThrottle).to receive(:call)
    allow(FeedRefreshScheduler).to receive(:enqueue)
    allow(TrimShowEpisodesScheduler).to receive(:enqueue)
    clear_enqueued_jobs
  end

  def fetched_episode(id, published_at)
    OpenStruct.new(id: id, title: "Episode #{id}", description: nil, published_at: published_at.iso8601,
                   duration: 10_800, is_replay: false, url: "https://example.test/#{id}")
  end

  it "re-enqueues segment syncs for older episodes whose segments never synced" do
    Feed.create!(name: "Feed", show_external_id: 1124, max_episodes: 10)
    show = Show.create!(external_id: 1124, title: "Tout un matin", ohdio_type: "emission_premiere")
    older = (3..8).to_h { |n| [ n, show.episodes.create!(ohdio_episode_id: "ep-#{n}", published_at: n.days.ago) ] }
    older[4].update!(has_valid_segments: false)        # synced, Ohdio had no segments: not retried
    older[5].segments.create!(title: "Chronique", position: 1) # already has segments
    # ep-3, ep-6, ep-7, ep-8 never got their segments

    fetched = OpenStruct.new(title: "Tout un matin", description: nil, image_url: nil, type: "emission_premiere",
                             page_size: 2, total_episodes: 8, url: nil, page: 1,
                             episodes: [ fetched_episode("ep-1", 1.day.ago), fetched_episode("ep-2", 2.days.ago) ])
    allow(Ohdio::Fetcher).to receive(:fetch).with(1124, page: 1).and_return(fetched)

    described_class.new(show_external_id: 1124).call

    segment_jobs = enqueued_jobs.select { |job| job[:job] == SyncEpisodeSegmentsJob }.map { |job| job[:args].first(2) }
    ids = show.episodes.pluck(:ohdio_episode_id, :id).to_h

    # Page 1 episodes are always synced; missing older ones get a page hint from their position
    # (newest first, 2 per page: ep-3 is 3rd => page 2, ep-6 6th => page 3, ep-7/ep-8 => page 4).
    expect(segment_jobs).to contain_exactly(
      [ ids["ep-1"], 1 ], [ ids["ep-2"], 1 ],
      [ ids["ep-3"], 2 ], [ ids["ep-6"], 3 ], [ ids["ep-7"], 4 ], [ ids["ep-8"], 4 ]
    )
  end

  it "does not look for missing segments when syncing later pages" do
    Feed.create!(name: "Feed", show_external_id: 1124, max_episodes: 10)
    show = Show.create!(external_id: 1124, title: "Tout un matin", ohdio_type: "emission_premiere")
    show.episodes.create!(ohdio_episode_id: "ep-9", published_at: 9.days.ago)

    fetched = OpenStruct.new(title: "Tout un matin", description: nil, image_url: nil, type: "emission_premiere",
                             page_size: 2, total_episodes: 8, url: nil, page: 2, episodes: [])
    allow(Ohdio::Fetcher).to receive(:fetch).with(1124, type: :emission_premiere, page: 2).and_return(fetched)

    described_class.new(show_external_id: 1124, type: "emission_premiere", page: 2).call

    expect(enqueued_jobs.select { |job| job[:job] == SyncEpisodeSegmentsJob }).to be_empty
  end
end
