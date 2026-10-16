require "rails_helper"

RSpec.describe "Version", type: :request do
  around do |example|
    AppVersion.instance_variable_set(:@to_h, nil)
    example.run
    AppVersion.instance_variable_set(:@to_h, nil)
  end

  it "reports the build from the image's build args" do
    stub_const("ENV", ENV.to_h.merge(
      "GIT_SHA" => "4570a44abc",
      "GIT_COMMITTED_AT" => "2026-10-15T22:17:00-04:00",
      "BUILT_AT" => "2026-10-16T02:19:30Z"
    ))

    get "/version"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "sha" => "4570a44abc",
      "committed_at" => "2026-10-15T22:17:00-04:00",
      "built_at" => "2026-10-16T02:19:30Z"
    )
  end

  it "falls back to git in a local checkout" do
    stub_const("ENV", ENV.to_h.except("GIT_SHA", "GIT_COMMITTED_AT", "BUILT_AT"))

    get "/version"

    expect(response.parsed_body["sha"]).to match(/\A\h{40}\z/)
    expect(response.parsed_body["built_at"]).to eq("unknown")
  end
end
