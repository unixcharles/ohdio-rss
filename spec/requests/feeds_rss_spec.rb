require 'rails_helper'

RSpec.describe 'Feeds RSS', type: :request do
  before do
    allow(FeedRefreshScheduler).to receive(:enqueue)
  end

  let(:feed) { Feed.create!(name: 'Test Feed', show_external_id: 123) }
  let!(:show) do
    Show.create!(
      external_id: 123,
      title: 'My Show',
      description: 'Show description',
      image_url: 'https://images.example.com/{width}/cover_{ratio}.jpg',
      ohdio_type: 'emission_premiere',
      url: 'https://ici.radio-canada.ca/ohdio/balados/1/my-show'
    )
  end

  it 'uses PUBLIC_BASE_URL for RSS and download links when configured' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('PUBLIC_BASE_URL').and_return('https://rss.example.com/')

    episode_resolved = show.episodes.create!(
      ohdio_episode_id: 'ep-2',
      title: 'Episode Two',
      description: 'Episode with segments',
      published_at: Time.zone.parse('2024-01-02 10:00:00'),
      is_replay: false,
      url: 'https://ici.radio-canada.ca/ohdio/balados/1/episode-two'
    )
    audio_content = AudioContent.create!(external_id: 'm1', audio_url: 'https://cdn.example.com/part-1.mp3', resolved: true, resolved_at: Time.current)
    episode_resolved.segments.create!(title: 'Part 1', duration: 30, seek_time: 0, audio_content_external_id: audio_content.external_id, position: 1)

    get "/rss/#{feed.uid}.rss"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<link>https://rss.example.com/rss/#{feed.uid}</link>")
    expect(response.body).to include("https://rss.example.com/downloads/#{feed.uid}/episodes/ep-2.mp3")
  end

  it 'falls back to request host when PUBLIC_BASE_URL is blank' do
    host! 'fallback.example.test'

    episode_resolved = show.episodes.create!(
      ohdio_episode_id: 'ep-2',
      title: 'Episode Two',
      description: 'Episode with segments',
      published_at: Time.zone.parse('2024-01-02 10:00:00'),
      is_replay: false,
      url: 'https://ici.radio-canada.ca/ohdio/balados/1/episode-two'
    )
    audio_content = AudioContent.create!(external_id: 'm1', audio_url: 'https://cdn.example.com/part-1.mp3', resolved: true, resolved_at: Time.current)
    episode_resolved.segments.create!(title: 'Part 1', duration: 30, seek_time: 0, audio_content_external_id: audio_content.external_id, position: 1)

    get "/rss/#{feed.uid}.rss"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<link>http://fallback.example.test/rss/#{feed.uid}</link>")
    expect(response.body).to include("http://fallback.example.test/downloads/#{feed.uid}/episodes/ep-2.mp3")
  end

  it 'renders RSS from replicated data and skips unresolved episodes' do
    episode_resolved = show.episodes.create!(
      ohdio_episode_id: 'ep-2',
      title: 'Episode Two',
      description: 'Episode with segments',
      published_at: Time.zone.parse('2024-01-02 10:00:00'),
      is_replay: false,
      url: 'https://ici.radio-canada.ca/ohdio/balados/1/episode-two'
    )

    audio_content = AudioContent.create!(external_id: 'm1', audio_url: 'https://cdn.example.com/part-1.mp3', resolved: true, resolved_at: Time.current)
    episode_resolved.segments.create!(title: 'Part 1', duration: 30, seek_time: 0, audio_content_external_id: audio_content.external_id, position: 1)

    episode_unresolved = show.episodes.create!(
      ohdio_episode_id: 'ep-3',
      title: 'Episode Three',
      description: 'Episode pending',
      published_at: Time.zone.parse('2024-01-03 10:00:00'),
      is_replay: false,
      url: 'https://ici.radio-canada.ca/ohdio/balados/1/episode-three'
    )
    episode_unresolved.segments.create!(title: 'Part A', duration: 30, seek_time: 0, audio_content_external_id: 'm2', position: 1)

    get "/rss/#{feed.uid}.rss"

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to include('application/xml')
    expect(response.body).to include('<title>Test Feed</title>')
    expect(response.body).to include('/downloads/')
    expect(response.body).to include('Episode Two')
    expect(response.body).not_to include('Episode Three')
    expect(FeedRefreshScheduler).to have_received(:enqueue).with(123)
  end

  it 'returns 404 when uid is unknown' do
    get '/rss/does-not-exist.rss'

    expect(response).to have_http_status(:not_found)
  end

  it 'respects feed max_episodes in RSS output' do
    feed.update!(max_episodes: 1)

    show.episodes.create!(
      ohdio_episode_id: 'ep-1',
      title: 'Newest Episode',
      is_replay: false,
      published_at: Time.zone.parse('2024-01-02 10:00:00'),
      audio_url: 'https://cdn.example.com/newest.mp3'
    )
    show.episodes.create!(
      ohdio_episode_id: 'ep-2',
      title: 'Older Episode',
      is_replay: false,
      published_at: Time.zone.parse('2024-01-01 10:00:00'),
      audio_url: 'https://cdn.example.com/older.mp3'
    )
    show.update!(ohdio_type: 'balado')

    get "/rss/#{feed.uid}.rss"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Newest Episode')
    expect(response.body).not_to include('Older Episode')
  end

  it 'filters RSS items by feed episode_query' do
    feed.update!(max_episodes: 10, episode_query: 'Simon OR Tyler AND NOT Frank')
    show.update!(ohdio_type: 'balado')

    show.episodes.create!(
      ohdio_episode_id: 'ep-1',
      title: 'Simon raconte',
      is_replay: false,
      audio_url: 'https://cdn.example.com/ep1.mp3'
    )
    show.episodes.create!(
      ohdio_episode_id: 'ep-2',
      title: 'Tyler et Frank',
      is_replay: false,
      audio_url: 'https://cdn.example.com/ep2.mp3'
    )
    show.episodes.create!(
      ohdio_episode_id: 'ep-3',
      title: 'Tyler raconte',
      is_replay: false,
      audio_url: 'https://cdn.example.com/ep3.mp3'
    )

    get "/rss/#{feed.uid}.rss"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Simon raconte')
    expect(response.body).to include('Tyler raconte')
    expect(response.body).not_to include('Tyler et Frank')
  end

  it 'builds emission RSS items from matching segments when segment_query is present' do
    feed.update!(segment_query: 'politique')

    matching_episode = show.episodes.create!(
      ohdio_episode_id: 'ep-match',
      title: 'Episode parent',
      is_replay: false
    )
    excluded_episode = show.episodes.create!(
      ohdio_episode_id: 'ep-excluded',
      title: 'Episode culture',
      is_replay: false
    )

    m1 = AudioContent.create!(external_id: 'm1', audio_url: 'https://cdn.example.com/part-1.mp3', resolved: true, resolved_at: Time.current)
    m2 = AudioContent.create!(external_id: 'm2', audio_url: 'https://cdn.example.com/part-2.mp3', resolved: true, resolved_at: Time.current)

    matching_segment = matching_episode.segments.create!(title: 'bloc politique', duration: 30, seek_time: 0, audio_content_external_id: m1.external_id, position: 1)
    excluded_episode.segments.create!(title: 'bloc culture', duration: 30, seek_time: 0, audio_content_external_id: m2.external_id, position: 1)

    get "/rss/#{feed.uid}.rss"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('bloc politique')
    expect(response.body).not_to include('Episode culture')
    expect(response.body).to include("/downloads/#{feed.uid}/segments/#{matching_segment.id}.mp3")
  end
end
