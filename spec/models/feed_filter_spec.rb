require 'rails_helper'

RSpec.describe FeedFilter, type: :model do
  before do
    allow(FeedRefreshScheduler).to receive(:enqueue)
  end

  def build_feed(**attrs)
    Feed.create!({ name: 'My Feed', show_external_id: 900 }.merge(attrs))
  end

  it 'is valid with a feed, kind and keyword' do
    filter = FeedFilter.new(feed: build_feed, kind: 'episode', keyword: 'Simon')

    expect(filter).to be_valid
  end

  it 'defaults include to true' do
    filter = build_feed.episode_filters.create!(keyword: 'Simon')

    expect(filter.include?).to be(true)
  end

  it 'is invalid without a keyword' do
    filter = FeedFilter.new(feed: build_feed, kind: 'episode', keyword: nil)

    expect(filter).not_to be_valid
    expect(filter.errors[:keyword]).to include("can't be blank")
  end

  it 'is invalid when keyword is too long' do
    filter = FeedFilter.new(feed: build_feed, kind: 'episode', keyword: 'a' * 101)

    expect(filter).not_to be_valid
    expect(filter.errors[:keyword]).to include('is too long (maximum is 100 characters)')
  end

  it 'is invalid with a kind outside episode/segment' do
    filter = FeedFilter.new(feed: build_feed, kind: 'show', keyword: 'Simon')

    expect(filter).not_to be_valid
    expect(filter.errors[:kind]).to include('is not included in the list')
  end

  describe 'scoped associations' do
    it 'sets kind automatically when built through feed.episode_filters' do
      filter = build_feed.episode_filters.create!(keyword: 'Simon')

      expect(filter.kind).to eq('episode')
    end

    it 'sets kind automatically when built through feed.segment_filters' do
      filter = build_feed.segment_filters.create!(keyword: 'politique')

      expect(filter.kind).to eq('segment')
    end

    it 'keeps episode and segment filters separate' do
      feed = build_feed
      feed.episode_filters.create!(keyword: 'Simon')
      feed.segment_filters.create!(keyword: 'politique')

      expect(feed.episode_filters.pluck(:keyword)).to eq([ 'Simon' ])
      expect(feed.segment_filters.pluck(:keyword)).to eq([ 'politique' ])
    end
  end
end
