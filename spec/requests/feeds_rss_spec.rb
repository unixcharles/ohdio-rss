require 'rails_helper'

RSpec.describe 'Feeds RSS', type: :request do
  let(:feed) { Feed.create!(name: 'Test Feed', show_id: 123) }

  let(:segment_one) do
    instance_double(
      Ohdio::Segment,
      title: 'Part 1',
      duration: 30,
      seek_time: 0,
      media_id: 'm1',
      audio_url: 'https://cdn.example.com/part-1.mp3'
    )
  end

  let(:segment_two) do
    instance_double(
      Ohdio::Segment,
      title: 'Part 2',
      duration: 60,
      seek_time: 30,
      media_id: 'm2',
      audio_url: 'https://cdn.example.com/part-2.mp3'
    )
  end

  let(:episode_with_audio) do
    instance_double(
      Ohdio::Episode,
      id: 'ep-1',
      title: 'Episode One',
      description: 'Episode description',
      published_at: '2024-01-01T10:00:00Z',
      is_replay: false,
      url: 'https://ici.radio-canada.ca/ohdio/balados/1/episode-one',
      audio_url: 'https://cdn.example.com/episode-one.mp3',
      segments: []
    )
  end

  let(:episode_with_segments) do
    instance_double(
      Ohdio::Episode,
      id: 'ep-2',
      title: 'Episode Two',
      description: 'Episode with segments',
      published_at: '2024-01-02T10:00:00Z',
      is_replay: false,
      url: 'https://ici.radio-canada.ca/ohdio/balados/1/episode-two',
      audio_url: nil,
      segments: [ segment_one, segment_two ]
    )
  end

  let(:replay_episode_with_segments) do
    instance_double(
      Ohdio::Episode,
      id: 'ep-replay',
      title: 'Replay Episode',
      description: 'Replay with segments',
      published_at: '2024-01-03T10:00:00Z',
      is_replay: true,
      url: 'https://ici.radio-canada.ca/ohdio/balados/1/replay-episode',
      audio_url: nil,
      segments: [ segment_one ]
    )
  end

  let(:show) do
    instance_double(
      Ohdio::Show,
      title: 'My Show',
      description: 'Show description',
      image_url: 'https://images.example.com/{width}/cover_{ratio}.jpg',
      type: 'emission_premiere',
      url: 'https://ici.radio-canada.ca/ohdio/balados/1/my-show',
      episodes: [ episode_with_audio, episode_with_segments, replay_episode_with_segments ]
    )
  end

  before do
    allow_any_instance_of(Feed).to receive(:show).and_return(show)
  end

  it 'renders RSS for a feed uid' do
    get "/rss/#{feed.uid}.rss"

    expect(response).to have_http_status(:ok)
    expect(response.content_type).to include('application/xml')
    expect(response.body).to include('<title>My Show</title>')
    expect(response.body).to include('<image>')
    expect(response.body).to include('<itunes:summary>Show description</itunes:summary>')
    expect(response.body).to include("<link>http://www.example.com/rss/#{feed.uid}</link>")
    expect(response.body).to include('https://images.example.com/w_210/cover_1x1.jpg')
    expect(response.body).to include('Episode Two')
    expect(response.body).to include("/downloads/#{feed.uid}/episodes/ep-2.mp3")
    expect(response.body).to include('type="audio/mpeg"')
    expect(response.body).not_to include('https://cdn.example.com/part-1.mp3')
    expect(response.body).not_to include('https://cdn.example.com/part-2.mp3')
    expect(response.body).not_to include('Replay Episode')

    enclosure_urls = response.body.scan(/<enclosure[^>]*url="([^"]+)"/).flatten
    expect(enclosure_urls.uniq).to eq(enclosure_urls)
  end

  it 'returns 404 when uid is unknown' do
    get '/rss/does-not-exist.rss'

    expect(response).to have_http_status(:not_found)
  end
end
