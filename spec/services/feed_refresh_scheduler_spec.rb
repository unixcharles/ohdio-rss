require 'rails_helper'

RSpec.describe FeedRefreshScheduler do
  before do
    Rails.cache.clear
    described_class.reset_memory_cache!
    clear_enqueued_jobs
  end

  it 'enqueues only once during throttle window' do
    described_class.enqueue(123)
    described_class.enqueue(123)

    expect(enqueued_jobs.count { |job| job[:job] == SyncShowJob }).to eq(1)
  end

  it 'enqueues immediately when forced' do
    described_class.enqueue(123)
    described_class.enqueue(123, force: true)

    expect(enqueued_jobs.count { |job| job[:job] == SyncShowJob }).to eq(2)
  end
end
