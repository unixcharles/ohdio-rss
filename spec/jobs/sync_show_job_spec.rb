require "rails_helper"

RSpec.describe SyncShowJob, type: :job do
  it "enqueues page jobs using highest max_episodes across feeds" do
    Feed.create!(name: "Feed A", show_external_id: 123, max_episodes: 50)
    Feed.create!(name: "Feed B", show_external_id: 123, max_episodes: 80)
    clear_enqueued_jobs

    show_record = instance_double(Show, external_id: 123, ohdio_type: "balado")
    fetched_show = instance_double(Ohdio::Show, page_size: 20, total_episodes: 500)
    service = instance_double(OhdioShowSyncService, call: [ show_record, fetched_show, { page_had_any_change: true } ])

    expect(OhdioShowSyncService).to receive(:new).with(show_external_id: 123, max_episodes: 80).and_return(service)

    described_class.perform_now(123)

    enqueued_pages = enqueued_jobs.filter_map do |job|
      next unless job[:job] == SyncShowPageJob

      job[:args][2]
    end

    expect(enqueued_pages).to eq([ 2, 3, 4 ])
  end

  it "caps effective max_episodes at 1000" do
    Feed.create!(name: "Feed A", show_external_id: 456, max_episodes: 1000)
    clear_enqueued_jobs

    show_record = instance_double(Show, external_id: 456, ohdio_type: "balado")
    fetched_show = instance_double(Ohdio::Show, page_size: 25, total_episodes: 5000)
    service = instance_double(OhdioShowSyncService, call: [ show_record, fetched_show, { page_had_any_change: true } ])

    expect(OhdioShowSyncService).to receive(:new).with(show_external_id: 456, max_episodes: 1000).and_return(service)

    described_class.perform_now(456)

    enqueued_pages = enqueued_jobs.count { |job| job[:job] == SyncShowPageJob }
    expect(enqueued_pages).to eq(39)
  end

  it "does not enqueue remaining pages when first page is unchanged" do
    Feed.create!(name: "Feed A", show_external_id: 987, max_episodes: 100)
    clear_enqueued_jobs

    show_record = instance_double(Show, external_id: 987, ohdio_type: "balado")
    fetched_show = instance_double(Ohdio::Show, page_size: 20, total_episodes: 500)
    service = instance_double(OhdioShowSyncService, call: [ show_record, fetched_show, { page_had_any_change: false } ])

    expect(OhdioShowSyncService).to receive(:new).with(show_external_id: 987, max_episodes: 100).and_return(service)

    described_class.perform_now(987)

    expect(enqueued_jobs.none? { |job| job[:job] == SyncShowPageJob }).to be(true)
  end
end
