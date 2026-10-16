require "rails_helper"

RSpec.describe ShowStalenessCheck do
  let(:show) { Show.create!(external_id: 654, title: "Daily", ohdio_type: "emission_premiere") }

  def daily_episodes(last_published_at)
    5.times do |index|
      show.episodes.create!(ohdio_episode_id: "ep-#{index}", published_at: last_published_at - index.days)
    end
  end

  it "flags a daily show that has gone a week without a new episode" do
    daily_episodes(7.days.ago)

    described_class.call(show)

    entry = show.sync_errors.sole
    expect(entry.kind).to eq("stale")
    expect(entry.message).to include("usually one every 1 day")
  end

  it "does not flag a daily show that published yesterday" do
    daily_episodes(1.day.ago)

    described_class.call(show)

    expect(show.sync_errors).to be_empty
  end

  it "does not flag shows that look like they have ended" do
    daily_episodes(120.days.ago)

    described_class.call(show)

    expect(show.sync_errors).to be_empty
  end

  it "skips chronological shows" do
    show.update!(ohdio_type: "audiobook")
    daily_episodes(7.days.ago)

    described_class.call(show)

    expect(show.sync_errors).to be_empty
  end
end
