require "rails_helper"

RSpec.describe OhdioApiThrottle do
  include ActiveSupport::Testing::TimeHelpers

  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow_any_instance_of(described_class).to receive(:rand).and_return(0.0)
  end

  it "increases cooldown after consecutive errors" do
    travel_to(Time.zone.parse("2026-04-14 12:00:00")) do
      service = described_class.new(cache: cache)

      service.register_error!
      first_until = cache.read(described_class::COOLDOWN_UNTIL_KEY)

      travel 1.second
      service.register_error!
      second_until = cache.read(described_class::COOLDOWN_UNTIL_KEY)

      expect(first_until).to be_present
      expect(second_until).to be > first_until
    end
  end

  it "waits for cooldown in addition to base interval" do
    travel_to(Time.zone.parse("2026-04-14 12:00:00")) do
      cache.write(described_class::LAST_REQUEST_AT_KEY, Time.current)
      cache.write(described_class::COOLDOWN_UNTIL_KEY, Time.current + 5.seconds)

      service = described_class.new(cache: cache, min_interval: 1.second)
      allow(service).to receive(:sleep)

      service.call

      expect(service).to have_received(:sleep).with(be_within(0.1).of(5.0))
    end
  end
end
