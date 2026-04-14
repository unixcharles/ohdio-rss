require 'rails_helper'

RSpec.describe Feed, type: :model do
  before do
    allow(FeedRefreshScheduler).to receive(:enqueue)
  end

  it 'is valid with name and show_id' do
    feed = described_class.new(name: 'My Feed', show_id: 123)

    expect(feed).to be_valid
  end

  it 'is invalid without a name' do
    feed = described_class.new(name: nil, show_id: 123)

    expect(feed).not_to be_valid
    expect(feed.errors[:name]).to include("can't be blank")
  end

  it 'is invalid without a show_id' do
    feed = described_class.new(name: 'My Feed', show_id: nil)

    expect(feed).not_to be_valid
    expect(feed.errors[:show_id]).to include("can't be blank")
  end

  it 'is invalid with a non-integer show_id' do
    feed = described_class.new(name: 'My Feed', show_id: 'show-123')

    expect(feed).not_to be_valid
    expect(feed.errors[:show_id]).to include('is not a number')
  end

  it 'allows duplicate show_id values' do
    described_class.create!(name: 'Existing Feed', show_id: 123)
    duplicate_feed = described_class.new(name: 'Duplicate Feed', show_id: 123)

    expect(duplicate_feed).to be_valid
  end

  it 'generates a uid on create' do
    feed = described_class.create!(name: 'My Feed', show_id: 123)

    expect(feed.uid).to be_present
  end

  it 'defaults exclude_replays to true' do
    feed = described_class.create!(name: 'My Feed', show_id: 124)

    expect(feed.exclude_replays).to be(true)
  end

  it 'defaults max_episodes to 100' do
    feed = described_class.create!(name: 'My Feed', show_id: 125)

    expect(feed.max_episodes).to eq(100)
  end

  it 'is invalid when max_episodes is above 1000' do
    feed = described_class.new(name: 'My Feed', show_id: 126, max_episodes: 1001)

    expect(feed).not_to be_valid
    expect(feed.errors[:max_episodes]).to include('must be less than or equal to 1000')
  end

  it 'is invalid when episode_query is too long' do
    feed = described_class.new(name: 'My Feed', show_id: 127, episode_query: 'a' * 501)

    expect(feed).not_to be_valid
    expect(feed.errors[:episode_query]).to include('is too long (maximum is 500 characters)')
  end

  it 'is invalid when segment_query is too long' do
    feed = described_class.new(name: 'My Feed', show_id: 128, segment_query: 'a' * 501)

    expect(feed).not_to be_valid
    expect(feed.errors[:segment_query]).to include('is too long (maximum is 500 characters)')
  end

  it 'is invalid with a duplicate uid' do
    existing_feed = described_class.create!(name: 'Existing Feed', show_id: 123)
    duplicate_feed = described_class.new(name: 'Duplicate Feed', show_id: 456, uid: existing_feed.uid)

    expect(duplicate_feed).not_to be_valid
    expect(duplicate_feed.errors[:uid]).to include('has already been taken')
  end

  describe '#show' do
    it 'maps feed.show_id to show.ohdio_id' do
      show = Show.create!(ohdio_id: 123, title: 'Fetched Show')
      feed = described_class.create!(name: 'My Feed', show_id: 123)

      expect(feed.show).to eq(show)
    end
  end

  describe '#filtered_episodes' do
    it 'filters episodes by episode_query' do
      show = Show.create!(ohdio_id: 888, title: 'Query Show')
      feed = described_class.create!(name: 'My Feed', show_id: 888, episode_query: 'Simon OR Tyler AND NOT Frank')

      show.episodes.create!(ohdio_episode_id: 'ep-1', title: 'Simon raconte', position: 1)
      show.episodes.create!(ohdio_episode_id: 'ep-2', title: 'Tyler et Frank', position: 2)
      show.episodes.create!(ohdio_episode_id: 'ep-3', title: 'Tyler raconte', position: 3)

      expect(feed.filtered_episodes(show: show).pluck(:ohdio_episode_id)).to eq([ 'ep-1', 'ep-3' ])
    end

    it 'filters out emission episodes without valid segments' do
      show = Show.create!(ohdio_id: 889, title: 'Emission Show', ohdio_type: 'emission_premiere')
      feed = described_class.create!(name: 'My Feed', show_id: 889)

      show.episodes.create!(ohdio_episode_id: 'ep-1', title: 'Valid', position: 1, has_valid_segments: true)
      show.episodes.create!(ohdio_episode_id: 'ep-2', title: 'Invalid', position: 2, has_valid_segments: false)

      expect(feed.filtered_episodes(show: show).pluck(:ohdio_episode_id)).to eq([ 'ep-1' ])
    end
  end

  describe '#filtered_segments_for_episode' do
    it 'returns all valid segments when segment_query is blank' do
      show = Show.create!(ohdio_id: 890, title: 'Emission Show', ohdio_type: 'emission_premiere')
      feed = described_class.create!(name: 'My Feed', show_id: 890)
      episode = show.episodes.create!(ohdio_episode_id: 'ep-1', position: 1, has_valid_segments: true)

      episode.segments.create!(title: 'politique', media_id: 'm1', seek_time: 0, duration: 20, position: 1)
      episode.segments.create!(title: 'invalide', media_id: nil, seek_time: 10, duration: 20, position: 2)

      expect(feed.filtered_segments_for_episode(episode: episode).pluck(:title)).to eq([ 'politique' ])
    end

    it 'filters valid segments using segment_query' do
      show = Show.create!(ohdio_id: 891, title: 'Emission Show', ohdio_type: 'emission_premiere')
      feed = described_class.create!(name: 'My Feed', show_id: 891, segment_query: 'politique')
      episode = show.episodes.create!(ohdio_episode_id: 'ep-1', position: 1, has_valid_segments: true)

      episode.segments.create!(title: 'bloc politique', media_id: 'm1', seek_time: 0, duration: 20, position: 1)
      episode.segments.create!(title: 'bloc culture', media_id: 'm2', seek_time: 10, duration: 20, position: 2)

      expect(feed.filtered_segments_for_episode(episode: episode).pluck(:title)).to eq([ 'bloc politique' ])
    end
  end

  describe 'sync enqueue callbacks' do
    it 'enqueues a sync on create' do
      described_class.create!(name: 'My Feed', show_id: 123)

      expect(FeedRefreshScheduler).to have_received(:enqueue).with(123, force: true)
    end

    it 'enqueues a sync when show_id changes' do
      feed = described_class.create!(name: 'My Feed', show_id: 123)
      allow(FeedRefreshScheduler).to receive(:enqueue)

      feed.update!(show_id: 456)

      expect(FeedRefreshScheduler).to have_received(:enqueue).with(456, force: true)
    end

    it 'does not enqueue when show_id is unchanged' do
      feed = described_class.create!(name: 'My Feed', show_id: 123)
      expect(FeedRefreshScheduler).to have_received(:enqueue).once

      feed.update!(name: 'Updated')

      expect(FeedRefreshScheduler).to have_received(:enqueue).once
    end
  end

  describe '.search_ohdio' do
    it 'searches Ohdio with the provided query and filter' do
      show = Ohdio::Show.new(id: 777, title: 'Cached Show', type: 'balado')

      expect(Ohdio::Searcher).to receive(:search).once.with('science', filter: :balado).and_return([ show ])

      expect(described_class.search_ohdio('science', filter: :balado)).to eq([ show ])
    end

    it 'returns an empty array for blank query' do
      expect(Ohdio::Searcher).not_to receive(:search)

      expect(described_class.search_ohdio('   ', filter: :all)).to eq([])
    end
  end
end
