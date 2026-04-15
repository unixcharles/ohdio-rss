require 'rails_helper'

RSpec.describe 'Feeds CRUD', type: :request do
  before do
    allow(FeedRefreshScheduler).to receive(:enqueue)
  end

  it 'lists feeds' do
    Feed.create!(name: 'Daily News', show_external_id: 1001)

    get '/feeds'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Daily News')
    expect(response.body).to include('action="/search"')
    expect(response.body).to include('name="q"')
  end

  it 'creates a feed' do
    expect do
      post '/feeds', params: { feed: { name: 'Morning Show', show_external_id: 1002 } }
    end.to change(Feed, :count).by(1)

    expect(response).to redirect_to(feed_path(Feed.last))
    expect(Feed.last.exclude_replays).to be(true)
    expect(Feed.last.max_episodes).to eq(100)
  end

  it 'creates a feed with exclude_replays disabled' do
    post '/feeds', params: { feed: { name: 'No Filter Feed', show_external_id: 1006, exclude_replays: '0', max_episodes: 50, episode_query: 'Simon' } }

    expect(response).to redirect_to(feed_path(Feed.last))
    expect(Feed.last.exclude_replays).to be(false)
    expect(Feed.last.max_episodes).to eq(50)
    expect(Feed.last.episode_query).to eq('Simon')
  end

  it 'searches shows on search page with query and filter' do
    show_result = Ohdio::Show.new(id: 2001, title: 'Science Show', type: 'balado')
    allow(Ohdio::Searcher).to receive(:search).with('science', filter: :balado).and_return([ show_result ])

    get '/search', params: { q: 'science', filter: 'balado' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Results for "science"')
    expect(response.body).to include('Science Show')
    expect(response.body).to include('/feeds/new?')
    expect(response.body).to include('show_external_id=2001')
  end

  it 'shows replicated metadata and links to episodes page' do
    feed = Feed.create!(name: 'Metadata Feed', show_external_id: 3001)
    show = Show.create!(external_id: 3001, title: 'Metadata Show', description: 'All metadata here', image_url: 'https://example.com/image.jpg', ohdio_type: 'balado', page_size: 10, total_episodes: 1, url: 'https://example.com/show')
    show.episodes.create!(
      ohdio_episode_id: 'ep-1',
      title: 'Episode 1: First show episode',
      description: 'Opening description',
      published_at: Time.zone.parse('2024-01-01 10:00:00'),
      audio_url: 'https://example.com/ep-1.mp3'
    )

    get "/feeds/#{feed.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Metadata Show')
    expect(response.body).to include('First show episode')
    expect(response.body).to include('Episode list')
    expect(response.body).to include("/feeds/#{feed.id}/episodes")
    expect(FeedRefreshScheduler).to have_received(:enqueue).with(3001)
  end

  it 'paginates episodes in newest-first order on episodes page' do
    feed = Feed.create!(name: 'Episode Feed', show_external_id: 3002)
    show = Show.create!(external_id: 3002, title: 'Episode Show', ohdio_type: 'emission_premiere')

    (1..22).each do |i|
      episode = show.episodes.create!(
        ohdio_episode_id: "ep-#{i}",
        title: "Episode #{i}",
        description: "Description #{i}",
        published_at: Time.zone.parse('2024-01-01 10:00:00') + i.days,
        duration: i * 60,
        is_replay: false,
        url: "https://example.com/ep-#{i}"
      )
      audio_content = AudioContent.create!(external_id: "m-#{i}", audio_url: "https://cdn.example.com/m-#{i}.mp3", resolved: true, resolved_at: Time.current)
      episode.segments.create!(audio_content_external_id: audio_content.external_id, duration: 60, position: 1)
    end

    get "/feeds/#{feed.id}/episodes"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Episode 22')
    expect(response.body).to include('Episode 3')
    expect(response.body).not_to include("/feeds/#{feed.id}/episodes/ep-2/segments")
    expect(response.body).to include('?page=2')
    expect(response.body).to include("/feeds/#{feed.id}/episodes/ep-22/segments")
    expect(response.body).to include("/downloads/#{feed.uid}/episodes/ep-22.mp3")

    get "/feeds/#{feed.id}/episodes", params: { page: 2 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Episode 2')
    expect(response.body).to include('Episode 1')
    expect(response.body).not_to include("/feeds/#{feed.id}/episodes/ep-3/segments")
  end

  it 'limits episode list to feed max_episodes' do
    feed = Feed.create!(name: 'Limited Feed', show_external_id: 3005, max_episodes: 5)
    show = Show.create!(external_id: 3005, title: 'Limited Show', ohdio_type: 'emission_premiere')

    (1..8).each do |i|
      episode = show.episodes.create!(
        ohdio_episode_id: "ep-#{i}",
        title: "Episode #{i}",
        description: "Description #{i}",
        published_at: Time.zone.parse('2024-01-01 10:00:00') + i.days,
        duration: i * 60,
        is_replay: false,
        url: "https://example.com/ep-#{i}"
      )
      audio_content = AudioContent.create!(external_id: "lm-#{i}", audio_url: "https://cdn.example.com/lm-#{i}.mp3", resolved: true, resolved_at: Time.current)
      episode.segments.create!(audio_content_external_id: audio_content.external_id, duration: 60, position: 1)
    end

    get "/feeds/#{feed.id}/episodes"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Episode 8')
    expect(response.body).to include('Episode 4')
    expect(response.body).not_to include("/feeds/#{feed.id}/episodes/ep-3/segments")
    expect(response.body).not_to include('?page=2')
  end

  it 'strips numeric episode prefix from displayed title' do
    feed = Feed.create!(name: 'Prefix Feed', show_external_id: 3006)
    show = Show.create!(external_id: 3006, title: 'Prefix Show', ohdio_type: 'emission_premiere')
    episode = show.episodes.create!(
      ohdio_episode_id: 'ep-1',
      title: 'Episode 1: Simon et Tyler racontent',
      is_replay: false
    )
    audio_content = AudioContent.create!(external_id: 'prefix-1', audio_url: 'https://cdn.example.com/prefix-1.mp3', resolved: true, resolved_at: Time.current)
    episode.segments.create!(audio_content_external_id: audio_content.external_id, duration: 60, position: 1)

    get "/feeds/#{feed.id}/episodes"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Simon et Tyler racontent')
    expect(response.body).not_to include('Episode 1: Simon et Tyler racontent')
  end

  it 'strips html tags from displayed episode title' do
    feed = Feed.create!(name: 'Html Title Feed', show_external_id: 3007)
    show = Show.create!(external_id: 3007, title: 'Html Show', ohdio_type: 'emission_premiere')
    episode = show.episodes.create!(
      ohdio_episode_id: 'ep-1',
      title: '<strong>Episode 1:</strong> <em>Simon et Tyler racontent</em>',
      is_replay: false
    )
    audio_content = AudioContent.create!(external_id: 'html-1', audio_url: 'https://cdn.example.com/html-1.mp3', resolved: true, resolved_at: Time.current)
    episode.segments.create!(audio_content_external_id: audio_content.external_id, duration: 60, position: 1)

    get "/feeds/#{feed.id}/episodes"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Simon et Tyler racontent')
    expect(response.body).not_to include('&lt;strong&gt;')
    expect(response.body).not_to include('&lt;em&gt;')
    expect(response.body).not_to include('Episode 1: Simon et Tyler racontent')
  end

  it 'normalizes escaped nonbreaking spaces in displayed episode title' do
    feed = Feed.create!(name: 'Escaped Title Feed', show_external_id: 3008)
    show = Show.create!(external_id: 3008, title: 'Escaped Show', ohdio_type: 'emission_premiere')
    episode = show.episodes.create!(
      ohdio_episode_id: 'ep-1',
      title: 'Mardi 14 avr. 2026&amp;nbsp;:&amp;nbsp;Chronique',
      is_replay: false
    )
    audio_content = AudioContent.create!(external_id: 'escaped-1', audio_url: 'https://cdn.example.com/escaped-1.mp3', resolved: true, resolved_at: Time.current)
    episode.segments.create!(audio_content_external_id: audio_content.external_id, duration: 60, position: 1)

    get "/feeds/#{feed.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Mardi 14 avr. 2026 : Chronique')
    expect(response.body).not_to include('&amp;nbsp;')
  end

  it 'shows segments for a selected episode with unresolved status' do
    feed = Feed.create!(name: 'Segment Feed', show_external_id: 3003)
    show = Show.create!(external_id: 3003, title: 'Segment Show', ohdio_type: 'emission_premiere')
    episode = show.episodes.create!(ohdio_episode_id: 'ep-1', title: 'Episode 1', is_replay: false)
    episode.segments.create!(title: 'Segment 1', duration: 45, seek_time: 10, audio_content_external_id: 'media-1', position: 1)

    get "/feeds/#{feed.id}/episodes/ep-1/segments"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Episode 1')
    expect(response.body).to include('Segment 1')
    expect(response.body).to include('Resolving in background')
  end

  it 'returns 404 for unknown episode segments page' do
    feed = Feed.create!(name: 'Missing Segment Feed', show_external_id: 3004)
    show = Show.create!(external_id: 3004, title: 'Missing Show', ohdio_type: 'emission_premiere')
    show.episodes.create!(ohdio_episode_id: 'ep-1', title: 'Episode 1', is_replay: false)

    get "/feeds/#{feed.id}/episodes/unknown/segments"

    expect(response).to have_http_status(:not_found)
  end

  it 'filters episodes using feed episode_query' do
    feed = Feed.create!(name: 'Query Feed', show_external_id: 3010, episode_query: 'Simon OR Tyler AND NOT Frank')
    show = Show.create!(external_id: 3010, title: 'Query Show', ohdio_type: 'emission_premiere')
    ep1 = show.episodes.create!(ohdio_episode_id: 'ep-1', title: 'Simon parle')
    ep2 = show.episodes.create!(ohdio_episode_id: 'ep-2', title: 'Tyler et Frank')
    ep3 = show.episodes.create!(ohdio_episode_id: 'ep-3', title: 'Tyler parle')
    m1 = AudioContent.create!(external_id: 'q1', audio_url: 'https://cdn.example.com/q1.mp3', resolved: true, resolved_at: Time.current)
    m2 = AudioContent.create!(external_id: 'q2', audio_url: 'https://cdn.example.com/q2.mp3', resolved: true, resolved_at: Time.current)
    m3 = AudioContent.create!(external_id: 'q3', audio_url: 'https://cdn.example.com/q3.mp3', resolved: true, resolved_at: Time.current)
    ep1.segments.create!(audio_content_external_id: m1.external_id, duration: 60, position: 1)
    ep2.segments.create!(audio_content_external_id: m2.external_id, duration: 60, position: 1)
    ep3.segments.create!(audio_content_external_id: m3.external_id, duration: 60, position: 1)

    get "/feeds/#{feed.id}/episodes"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Simon parle')
    expect(response.body).to include('Tyler parle')
    expect(response.body).not_to include('Tyler et Frank')
  end

  it 'deletes a feed' do
    feed = Feed.create!(name: 'To Remove', show_external_id: 1004)

    expect do
      delete "/feeds/#{feed.id}"
    end.to change(Feed, :count).by(-1)

    expect(response).to redirect_to(feeds_path)
  end
end
