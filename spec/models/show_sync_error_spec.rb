require "rails_helper"

RSpec.describe ShowSyncError do
  let(:show) { Show.create!(external_id: 321, title: "Tout un matin", ohdio_type: "emission_premiere") }

  it "folds repeats of the same problem into one entry" do
    described_class.record!(show, kind: "sync_failed", message: "Page 1: PersistedQueryNotFound")

    travel 15.minutes do
      described_class.record!(show, kind: "sync_failed", message: "Page 1: PersistedQueryNotFound")
    end

    expect(show.sync_errors.count).to eq(1)
    expect(show.sync_errors.first.occurrences).to eq(2)
  end

  it "adds a new entry when the message changes" do
    described_class.record!(show, kind: "sync_failed", message: "first")
    described_class.record!(show, kind: "sync_failed", message: "second")

    expect(show.sync_errors.newest_first.pluck(:message)).to eq(%w[second first])
  end

  it "prunes entries past the retention window" do
    travel_to(40.days.ago) { described_class.record!(show, kind: "stale", message: "old") }
    described_class.record!(show, kind: "sync_failed", message: "new")

    expect(show.sync_errors.pluck(:message)).to eq([ "new" ])
  end

  it "never raises from safely_record" do
    expect { described_class.safely_record(show, kind: "bogus", message: "x") }.not_to raise_error
    expect(show.sync_errors.count).to eq(0)
  end
end
