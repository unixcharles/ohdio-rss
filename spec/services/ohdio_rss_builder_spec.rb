require 'rails_helper'

RSpec.describe OhdioRssBuilder do
  let(:base_url) { 'http://example.test' }

  before do
    allow(FeedRefreshScheduler).to receive(:enqueue)
  end

  it 'builds emission_premiere RSS with merged mp3 enclosures' do
    show = Show.create!(external_id: 1, title: 'My Show', description: 'Show description', ohdio_type: 'emission_premiere')
    episode = show.episodes.create!(
      ohdio_episode_id: 'ep-2',
      title: 'Episode Two',
      description: 'Episode with segments',
      published_at: Time.zone.parse('2024-01-02 10:00:00'),
      is_replay: false,
      url: 'https://ici.radio-canada.ca/ohdio/balados/1/episode-two'
    )
    audio_content = AudioContent.create!(external_id: 'm1', audio_url: 'https://cdn.example.com/part-1.mp3', resolved: true, resolved_at: Time.current)
    episode.segments.create!(audio_content_external_id: audio_content.external_id, duration: 60, position: 1)

    feed = Feed.create!(name: 'Test Feed', show_external_id: 1)

    xml = described_class.new(feed: feed, base_url: base_url).generate

    expect(xml).to include("<link>#{base_url}/rss/#{feed.uid}</link>")
    expect(xml).to include("#{base_url}/downloads/#{feed.uid}/episodes/ep-2.mp3")
    expect(xml).to include('type="audio/mpeg"')
  end

  it 'builds non-emission RSS items with direct audio URLs' do
    show = Show.create!(external_id: 2, title: 'My Podcast', description: 'Podcast description', ohdio_type: 'balado')
    show.episodes.create!(
      ohdio_episode_id: 'ep-1',
      title: 'Episode One',
      description: 'Episode description',
      published_at: Time.zone.parse('2024-01-01 10:00:00'),
      duration: 120,
      is_replay: false,
      url: 'https://ici.radio-canada.ca/ohdio/balados/1/episode-one',
      audio_url: 'https://cdn.example.com/episode-one.mp3'
    )
    feed = Feed.create!(name: 'Test Feed', show_external_id: 2)

    xml = described_class.new(feed: feed, base_url: base_url).generate

    expect(xml).to include('https://cdn.example.com/episode-one.mp3')
    expect(xml).to include('type="audio/mpeg"')
  end

  it 'filters replay episodes when feed excludes replays' do
    show = Show.create!(external_id: 3, title: 'My Show', description: 'Show description', ohdio_type: 'emission_premiere')
    replay = show.episodes.create!(
      ohdio_episode_id: 'ep-replay',
      title: 'Replay Episode',
      description: 'Replay',
      published_at: Time.zone.parse('2024-01-03 10:00:00'),
      is_replay: true
    )
    audio_content = AudioContent.create!(external_id: 'm9', audio_url: 'https://cdn.example.com/replay.mp3', resolved: true, resolved_at: Time.current)
    replay.segments.create!(audio_content_external_id: audio_content.external_id, duration: 30, position: 1)

    feed = Feed.create!(name: 'Test Feed', show_external_id: 3)

    xml = described_class.new(feed: feed, base_url: base_url).generate

    expect(xml).not_to include('Replay Episode')
  end

  it 'limits RSS items to feed max_episodes' do
    show = Show.create!(external_id: 4, title: 'Limited Show', description: 'Show description', ohdio_type: 'balado')
    show.episodes.create!(
      ohdio_episode_id: 'ep-1',
      title: 'Newest Episode',
      is_replay: false,
      audio_url: 'https://cdn.example.com/newest.mp3',
      published_at: Time.zone.parse('2024-01-02 10:00:00')
    )
    show.episodes.create!(
      ohdio_episode_id: 'ep-2',
      title: 'Older Episode',
      is_replay: false,
      audio_url: 'https://cdn.example.com/older.mp3',
      published_at: Time.zone.parse('2024-01-01 10:00:00')
    )

    feed = Feed.create!(name: 'Test Feed', show_external_id: 4, max_episodes: 1)

    xml = described_class.new(feed: feed, base_url: base_url).generate

    expect(xml).to include('Newest Episode')
    expect(xml).not_to include('Older Episode')
  end

  it 'strips numeric episode prefix in RSS item titles' do
    show = Show.create!(external_id: 5, title: 'Prefix Show', description: 'Show description', ohdio_type: 'balado')
    show.episodes.create!(
      ohdio_episode_id: 'ep-1',
      title: 'Episode 1: Simon et Tyler racontent',
      is_replay: false,
      audio_url: 'https://cdn.example.com/episode.mp3'
    )

    feed = Feed.create!(name: 'Test Feed', show_external_id: 5)

    xml = described_class.new(feed: feed, base_url: base_url).generate

    expect(xml).to include('<title>Simon et Tyler racontent</title>')
    expect(xml).not_to include('Episode 1: Simon et Tyler racontent')
  end

  it 'strips html tags in RSS item titles' do
    show = Show.create!(external_id: 6, title: 'HTML Prefix Show', description: 'Show description', ohdio_type: 'balado')
    show.episodes.create!(
      ohdio_episode_id: 'ep-1',
      title: '<strong>Episode 1:</strong> <em>Simon et Tyler racontent</em>',
      is_replay: false,
      audio_url: 'https://cdn.example.com/episode.mp3'
    )

    feed = Feed.create!(name: 'Test Feed', show_external_id: 6)

    xml = described_class.new(feed: feed, base_url: base_url).generate

    expect(xml).to include('<title>Simon et Tyler racontent</title>')
    expect(xml).not_to include('<strong>')
    expect(xml).not_to include('<em>')
  end

  it 'emits one RSS item per matching segment when segment_query is set' do
    show = Show.create!(external_id: 7, title: 'Segment Show', description: 'Show description', ohdio_type: 'emission_premiere')
    episode = show.episodes.create!(
      ohdio_episode_id: 'ep-1',
      title: 'Episode parent',
      is_replay: false,
      has_valid_segments: true
    )
    matching_medium = AudioContent.create!(external_id: 'm1', audio_url: 'https://cdn.example.com/segment-1.mp3', resolved: true, resolved_at: Time.current)
    skipped_medium = AudioContent.create!(external_id: 'm2', audio_url: 'https://cdn.example.com/segment-2.mp3', resolved: true, resolved_at: Time.current)
    matching_segment = episode.segments.create!(title: 'bloc politique', duration: 30, seek_time: 0, audio_content_external_id: matching_medium.external_id, position: 1)
    episode.segments.create!(title: 'bloc culture', duration: 30, seek_time: 0, audio_content_external_id: skipped_medium.external_id, position: 2)

    feed = Feed.create!(name: 'Test Feed', show_external_id: 7, segment_query: 'politique')

    xml = described_class.new(feed: feed, base_url: base_url).generate

    expect(xml).to include('<title>bloc politique</title>')
    expect(xml).not_to include('<title>Episode parent</title>')
    expect(xml).to include("#{base_url}/downloads/#{feed.uid}/segments/#{matching_segment.id}.mp3")
  end
end
