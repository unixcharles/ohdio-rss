require "rails_helper"
require "tmpdir"

RSpec.describe "Downloads", type: :request do
  let(:feed) { Feed.create!(name: "Test Feed", show_id: 123) }

  let(:segment_one) do
    instance_double(
      Ohdio::Segment,
      media_id: "m1",
      audio_url: "https://cdn.example.com/part-1.mp3"
    )
  end

  let(:segment_two) do
    instance_double(
      Ohdio::Segment,
      media_id: "m2",
      audio_url: "https://cdn.example.com/part-2.mp3"
    )
  end

  let(:episode_with_segments) do
    instance_double(
      Ohdio::Episode,
      id: "ep-2",
      is_replay: false,
      segments: [ segment_one, segment_two ]
    )
  end

  let(:replay_episode_with_segments) do
    instance_double(
      Ohdio::Episode,
      id: "ep-replay",
      is_replay: true,
      segments: [ segment_one ]
    )
  end

  let(:show) do
    instance_double(
      Ohdio::Show,
      episodes: [ episode_with_segments, replay_episode_with_segments ]
    )
  end

  before do
    allow_any_instance_of(Feed).to receive(:show).and_return(show)
  end

  it "downloads a merged episode mp3" do
    Dir.mktmpdir do |tmpdir|
      merged_path = File.join(tmpdir, "merged.mp3")
      File.write(merged_path, "merged-audio")

      joiner = instance_double(RemoteAudioFileJoiner, call: merged_path)
      expect(RemoteAudioFileJoiner).to receive(:new).with(urls: [
        "https://cdn.example.com/part-1.mp3",
        "https://cdn.example.com/part-2.mp3"
      ]).and_return(joiner)

      get "/downloads/#{feed.uid}/episodes/ep-2.mp3"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("audio/mpeg")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include("#{feed.uid}-ep-2.mp3")
      expect(response.body).to eq("merged-audio")
    end
  end

  it "returns 404 when episode is unknown" do
    get "/downloads/#{feed.uid}/episodes/unknown.mp3"

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for replay episode by default" do
    get "/downloads/#{feed.uid}/episodes/ep-replay.mp3"

    expect(response).to have_http_status(:not_found)
  end

  it "allows replay episode download when exclude_replays is disabled" do
    feed.update!(exclude_replays: false)

    Dir.mktmpdir do |tmpdir|
      merged_path = File.join(tmpdir, "merged-replay.mp3")
      File.write(merged_path, "replay-audio")

      joiner = instance_double(RemoteAudioFileJoiner, call: merged_path)
      allow(RemoteAudioFileJoiner).to receive(:new).and_return(joiner)

      get "/downloads/#{feed.uid}/episodes/ep-replay.mp3"

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("replay-audio")
    end
  end
end
