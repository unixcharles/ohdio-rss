require 'rails_helper'
require 'tmpdir'

RSpec.describe 'Downloads', type: :request do
  before do
    allow(FeedRefreshScheduler).to receive(:enqueue)
  end

  let(:feed) { Feed.create!(name: 'Test Feed', show_external_id: 123) }
  let!(:show) { Show.create!(external_id: 123, title: 'Show', ohdio_type: 'emission_premiere') }
  let!(:episode) { show.episodes.create!(ohdio_episode_id: 'ep-2', is_replay: false, published_at: Time.zone.parse('2024-01-02 10:00:00')) }

  it 'downloads a merged episode mp3 when media is resolved' do
    medium_one = AudioContent.create!(external_id: 'm1', audio_url: 'https://cdn.example.com/part-1.mp3', resolved: true, resolved_at: Time.current)
    medium_two = AudioContent.create!(external_id: 'm2', audio_url: 'https://cdn.example.com/part-2.mp3', resolved: true, resolved_at: Time.current)
    episode.segments.create!(audio_content_external_id: medium_one.external_id, position: 1)
    episode.segments.create!(audio_content_external_id: medium_two.external_id, position: 2)

    Dir.mktmpdir do |tmpdir|
      merged_path = File.join(tmpdir, 'merged.mp3')
      File.write(merged_path, 'merged-audio')

      joiner = instance_double(RemoteAudioFileJoiner, call: merged_path)
      expect(RemoteAudioFileJoiner).to receive(:new).with(urls: [
        'https://cdn.example.com/part-1.mp3',
        'https://cdn.example.com/part-2.mp3'
      ]).and_return(joiner)

      get "/downloads/#{feed.uid}/episodes/ep-2.mp3"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('audio/mpeg')
      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.headers['Content-Disposition']).to include("#{feed.uid}-ep-2.mp3")
      expect(response.body).to eq('merged-audio')
      expect(FeedRefreshScheduler).to have_received(:enqueue).with(123)
    end
  end

  it 'downloads a single clipped segment when segment_query is present' do
    feed.update!(segment_query: 'politique')
    medium_one = AudioContent.create!(external_id: 'm1', audio_url: 'https://cdn.example.com/part-1.mp3', resolved: true, resolved_at: Time.current)
    medium_two = AudioContent.create!(external_id: 'm2', audio_url: 'https://cdn.example.com/part-2.mp3', resolved: true, resolved_at: Time.current)
    segment = episode.segments.create!(title: 'bloc politique', audio_content_external_id: medium_one.external_id, seek_time: 10, duration: 30, position: 1)
    episode.segments.create!(title: 'bloc culture', audio_content_external_id: medium_two.external_id, seek_time: 20, duration: 45, position: 2)

    Dir.mktmpdir do |tmpdir|
      merged_path = File.join(tmpdir, 'merged-filtered.mp3')
      File.write(merged_path, 'filtered-audio')

      joiner = instance_double(RemoteAudioSegmentJoiner, call: merged_path)
      expect(RemoteAudioSegmentJoiner).to receive(:new).with(segments: [
        {
          url: 'https://cdn.example.com/part-1.mp3',
          start_time: 10.0,
          duration: 30.0
        }
      ]).and_return(joiner)

      get "/downloads/#{feed.uid}/segments/#{segment.id}.mp3"

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('filtered-audio')
    end
  end

  it 'returns 404 when segment_query excludes all valid segments' do
    feed.update!(segment_query: 'politique')
    medium_one = AudioContent.create!(external_id: 'm1', audio_url: 'https://cdn.example.com/part-1.mp3', resolved: true, resolved_at: Time.current)
    segment = episode.segments.create!(title: 'bloc culture', audio_content_external_id: medium_one.external_id, seek_time: 10, duration: 30, position: 1)

    get "/downloads/#{feed.uid}/segments/#{segment.id}.mp3"

    expect(response).to have_http_status(:not_found)
  end

  it 'returns 404 on episode download when segment_query is present' do
    feed.update!(segment_query: 'politique')
    medium_one = AudioContent.create!(external_id: 'm1', audio_url: 'https://cdn.example.com/part-1.mp3', resolved: true, resolved_at: Time.current)
    episode.segments.create!(title: 'bloc politique', audio_content_external_id: medium_one.external_id, seek_time: 10, duration: 30, position: 1)

    get "/downloads/#{feed.uid}/episodes/ep-2.mp3"

    expect(response).to have_http_status(:not_found)
  end

  it 'returns 202 when segment media is unresolved' do
    AudioContent.create!(external_id: 'm1', resolved: false)
    episode.segments.create!(audio_content_external_id: 'm1', position: 1)

    get "/downloads/#{feed.uid}/episodes/ep-2.mp3"

    expect(response).to have_http_status(:accepted)
    expect(response.headers['Retry-After']).to eq('30')
  end

  it 'returns 404 when episode is unknown' do
    get "/downloads/#{feed.uid}/episodes/unknown.mp3"

    expect(response).to have_http_status(:not_found)
  end

  it 'returns 404 when episode exceeds feed max_episodes' do
    feed.update!(max_episodes: 1)
    older_episode = show.episodes.create!(ohdio_episode_id: 'ep-older', is_replay: false, published_at: Time.zone.parse('2024-01-01 10:00:00'))
    audio_content = AudioContent.create!(external_id: 'm4', audio_url: 'https://cdn.example.com/older.mp3', resolved: true, resolved_at: Time.current)
    older_episode.segments.create!(audio_content_external_id: audio_content.external_id, position: 1)

    get "/downloads/#{feed.uid}/episodes/ep-older.mp3"

    expect(response).to have_http_status(:not_found)
  end

  it 'returns 404 when episode is excluded by feed query' do
    feed.update!(episode_query: 'Simon')
    filtered_episode = show.episodes.create!(ohdio_episode_id: 'ep-filtered', is_replay: false)
    audio_content = AudioContent.create!(external_id: 'm5', audio_url: 'https://cdn.example.com/filtered.mp3', resolved: true, resolved_at: Time.current)
    filtered_episode.segments.create!(audio_content_external_id: audio_content.external_id, position: 1)

    get "/downloads/#{feed.uid}/episodes/ep-filtered.mp3"

    expect(response).to have_http_status(:not_found)
  end

  it 'returns 404 for replay episode by default' do
    replay = show.episodes.create!(ohdio_episode_id: 'ep-replay', is_replay: true)
    replay.segments.create!(audio_content_external_id: 'm1', position: 1)

    get "/downloads/#{feed.uid}/episodes/ep-replay.mp3"

    expect(response).to have_http_status(:not_found)
  end

  it 'allows replay episode download when exclude_replays is disabled' do
    feed.update!(exclude_replays: false)
    replay = show.episodes.create!(ohdio_episode_id: 'ep-replay', is_replay: true)
    audio_content = AudioContent.create!(external_id: 'm3', audio_url: 'https://cdn.example.com/replay.mp3', resolved: true, resolved_at: Time.current)
    replay.segments.create!(audio_content_external_id: audio_content.external_id, position: 1)

    Dir.mktmpdir do |tmpdir|
      merged_path = File.join(tmpdir, 'merged-replay.mp3')
      File.write(merged_path, 'replay-audio')

      joiner = instance_double(RemoteAudioFileJoiner, call: merged_path)
      allow(RemoteAudioFileJoiner).to receive(:new).and_return(joiner)

      get "/downloads/#{feed.uid}/episodes/ep-replay.mp3"

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('replay-audio')
    end
  end
end
