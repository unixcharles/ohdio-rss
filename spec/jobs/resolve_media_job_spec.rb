require "rails_helper"

RSpec.describe ResolveMediaJob, type: :job do
  before do
    allow(OhdioApiThrottle).to receive(:call)
    allow(OhdioApiThrottle).to receive(:register_error!)
  end

  it "registers global cooldown on non-429 Ohdio errors" do
    medium = Medium.create!(media_id: "media-1", resolved: false)
    client = instance_double(Ohdio::Client)

    allow(Ohdio::Client).to receive(:new).and_return(client)
    allow(client).to receive(:get_media_url).and_raise(Ohdio::ApiError, "HTTP 500: Internal Server Error")

    described_class.perform_now(medium.id)

    expect(OhdioApiThrottle).to have_received(:register_error!)
    expect(medium.reload.resolve_error).to include("HTTP 500")
  end

  it "registers global cooldown on 429 Ohdio errors" do
    medium = Medium.create!(media_id: "media-2", resolved: false)
    client = instance_double(Ohdio::Client)

    allow(Ohdio::Client).to receive(:new).and_return(client)
    allow(client).to receive(:get_media_url).and_raise(Ohdio::ApiError, "HTTP 429: Too Many Requests")

    described_class.perform_now(medium.id)

    expect(OhdioApiThrottle).to have_received(:register_error!)
    expect(medium.reload.resolve_error).to include("HTTP 429")
  end
end
