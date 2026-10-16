require "rails_helper"

RSpec.describe "Ohdio job deduplication" do
  {
    SyncShowJob => [ [ 1124 ], "SyncShowJob/1124" ],
    SyncShowPageJob => [ [ 1124, "emission_premiere", 3, 50 ], "SyncShowPageJob/1124-3" ],
    SyncEpisodeSegmentsJob => [ [ 42, 1, 50 ], "SyncEpisodeSegmentsJob/42" ],
    ResolveAudioContentJob => [ [ 7 ], "ResolveAudioContentJob/7" ],
    RefreshAllFeedsJob => [ [], "RefreshAllFeedsJob/all" ]
  }.each do |job_class, (arguments, expected_key)|
    it "#{job_class} discards an enqueue whose #{expected_key} job is already pending" do
      job = job_class.new(*arguments)

      expect(job.concurrency_key).to eq(expected_key)
      expect(job_class.concurrency_limit).to eq(1)
      expect(job_class.concurrency_on_conflict).to eq(:discard)
    end
  end

  it "keys segment syncs per episode, not per page hint" do
    expect(SyncEpisodeSegmentsJob.new(42, 1).concurrency_key).to eq(SyncEpisodeSegmentsJob.new(42, 2).concurrency_key)
  end

  it "runs the ohdio_api queue on its own single-threaded worker" do
    workers = ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/queue.yml"))["production"]["workers"]
    ohdio_worker = workers.find { |worker| worker["queues"] == "ohdio_api" }

    expect(ohdio_worker).to include("threads" => 1, "processes" => 1)
    expect(workers.flat_map { |worker| Array(worker["queues"]) }.count("ohdio_api")).to eq(1)
    expect(workers.flat_map { |worker| Array(worker["queues"]) }).not_to include("*")
  end
end
