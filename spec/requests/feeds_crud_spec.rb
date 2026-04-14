require 'rails_helper'

RSpec.describe 'Feeds CRUD', type: :request do
  it 'lists feeds' do
    Feed.create!(name: 'Daily News', show_id: 1001)

    get '/feeds'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Daily News')
  end

  it 'creates a feed' do
    expect do
      post '/feeds', params: { feed: { name: 'Morning Show', show_id: 1002 } }
    end.to change(Feed, :count).by(1)

    expect(response).to redirect_to(feed_path(Feed.last))
    expect(Feed.last.exclude_replays).to be(true)
  end

  it 'creates a feed with exclude_replays disabled' do
    post '/feeds', params: { feed: { name: 'No Filter Feed', show_id: 1006, exclude_replays: '0' } }

    expect(response).to redirect_to(feed_path(Feed.last))
    expect(Feed.last.exclude_replays).to be(false)
  end

  it 'searches shows on new page with query and filter' do
    show_result = Ohdio::Show.new(id: 2001, title: 'Science Show', type: 'balado')
    allow(Ohdio::Searcher).to receive(:search).with('science', filter: :balado).and_return([ show_result ])

    get '/feeds/new', params: { query: 'science', filter: 'balado' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Results for "science"')
    expect(response.body).to include('Science Show')
  end

  it 'allows creating multiple feeds for the same show_id' do
    post '/feeds', params: { feed: { name: 'Feed A', show_id: 2002 } }
    post '/feeds', params: { feed: { name: 'Feed B', show_id: 2002 } }

    expect(Feed.where(show_id: 2002).count).to eq(2)
    uids = Feed.where(show_id: 2002).pluck(:uid)
    expect(uids.uniq.size).to eq(2)
  end

  it 'shows show metadata and links to episodes page' do
    feed = Feed.create!(name: 'Metadata Feed', show_id: 3001)
    episode = Ohdio::Episode.new(id: 'ep-3001', title: 'Episode 3001', description: 'Episode details',
                                 published_at: '2024-01-10T10:00:00Z', duration: 1200, is_replay: false,
                                 url: 'https://example.com/ep-3001',
                                 segment_fetcher: -> { [] }, audio_url_fetcher: nil)
    show = Ohdio::Show.new(id: 3001, title: 'Metadata Show', description: 'All metadata here',
                           image_url: 'https://example.com/image.jpg', type: 'balado', page: 1, page_size: 1,
                           total_episodes: 1, episodes: [ episode ], url: 'https://example.com/show')

    allow_any_instance_of(Feed).to receive(:show).and_return(show)

    get "/feeds/#{feed.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Metadata Show')
    expect(response.body).to include('View first 5 episodes')
    expect(response.body).to include("/feeds/#{feed.id}/episodes")
  end

  it 'shows first 5 episodes in API order on episodes page' do
    feed = Feed.create!(name: 'Episode Feed', show_id: 3002)
    episodes = (1..6).map do |i|
      instance_double(
        Ohdio::Episode,
        id: "ep-#{i}",
        title: "Episode #{i}",
        description: "Description #{i}",
        published_at: "2024-01-0#{i}T10:00:00Z",
        duration: i * 60,
        is_replay: false,
        url: "https://example.com/ep-#{i}",
        audio_url: "https://cdn.example.com/ep-#{i}.mp3"
      )
    end
    show = instance_double(Ohdio::Show, episodes: episodes, type: 'emission_premiere')

    allow_any_instance_of(Feed).to receive(:show).and_return(show)

    get "/feeds/#{feed.id}/episodes"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Episode 1')
    expect(response.body).to include('Episode 5')
    expect(response.body).not_to include('Episode 6')
    expect(response.body).to include("/feeds/#{feed.id}/episodes/ep-1/segments")
  end

  it 'shows segments for a selected episode' do
    feed = Feed.create!(name: 'Segment Feed', show_id: 3003)
    segment = instance_double(
      Ohdio::Segment,
      title: 'Segment 1',
      duration: 45,
      seek_time: 10,
      media_id: 'media-1',
      audio_url: 'https://cdn.example.com/segment-1.mp3'
    )
    episode = instance_double(Ohdio::Episode, id: 'ep-1', title: 'Episode 1', is_replay: false, segments: [ segment ])
    show = instance_double(Ohdio::Show, episodes: [ episode ], type: 'emission_premiere')

    allow_any_instance_of(Feed).to receive(:show).and_return(show)

    get "/feeds/#{feed.id}/episodes/ep-1/segments"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Episode 1')
    expect(response.body).to include('Segment 1')
    expect(response.body).to include('Load audio URL')
    expect(response.body).not_to include('segment-1.mp3')
  end

  it 'resolves audio url for a requested segment media id' do
    cache_store = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(cache_store)

    feed = Feed.create!(name: 'Segment Feed', show_id: 3003)
    segment = instance_double(
      Ohdio::Segment,
      title: 'Segment 1',
      duration: 45,
      seek_time: 10,
      media_id: 'media-1',
      audio_url: 'https://cdn.example.com/segment-1.mp3'
    )
    expect(segment).to receive(:audio_url).once.and_return('https://cdn.example.com/segment-1.mp3')

    episode = instance_double(Ohdio::Episode, id: 'ep-1', title: 'Episode 1', is_replay: false, segments: [ segment ])
    show = instance_double(Ohdio::Show, episodes: [ episode ], type: 'emission_premiere')

    allow_any_instance_of(Feed).to receive(:show).and_return(show)

    get "/feeds/#{feed.id}/episodes/ep-1/segments", params: { resolve_media_id: 'media-1' }
    get "/feeds/#{feed.id}/episodes/ep-1/segments"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('segment-1.mp3#t=10,55')
  end

  it 'returns 404 for unknown episode segments page' do
    feed = Feed.create!(name: 'Missing Segment Feed', show_id: 3004)
    episode = instance_double(Ohdio::Episode, id: 'ep-1', title: 'Episode 1', is_replay: false, segments: [])
    show = instance_double(Ohdio::Show, episodes: [ episode ], type: 'emission_premiere')

    allow_any_instance_of(Feed).to receive(:show).and_return(show)

    get "/feeds/#{feed.id}/episodes/unknown/segments"

    expect(response).to have_http_status(:not_found)
  end

  it 'updates a feed' do
    feed = Feed.create!(name: 'Old Name', show_id: 1003)

    patch "/feeds/#{feed.id}", params: { feed: { name: 'New Name', show_id: 1003, exclude_replays: '0' } }

    expect(response).to redirect_to(feed_path(feed))
    expect(feed.reload.name).to eq('New Name')
    expect(feed.reload.exclude_replays).to be(false)
  end

  it 'deletes a feed' do
    feed = Feed.create!(name: 'To Remove', show_id: 1004)

    expect do
      delete "/feeds/#{feed.id}"
    end.to change(Feed, :count).by(-1)

    expect(response).to redirect_to(feeds_path)
  end
end
