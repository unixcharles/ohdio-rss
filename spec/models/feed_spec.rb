require 'rails_helper'

RSpec.describe Feed, type: :model do
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

  it 'is invalid with a duplicate uid' do
    existing_feed = described_class.create!(name: 'Existing Feed', show_id: 123)
    duplicate_feed = described_class.new(name: 'Duplicate Feed', show_id: 456, uid: existing_feed.uid)

    expect(duplicate_feed).not_to be_valid
    expect(duplicate_feed.errors[:uid]).to include('has already been taken')
  end

  describe '#show' do
    it 'fetches the show from Ohdio using show_id' do
      feed = described_class.new(name: 'My Feed', show_id: 123)
      fetched_show = Ohdio::Show.new(id: 123, title: 'Fetched Show', type: 'balado', episodes: [])

      expect(Ohdio::Fetcher).to receive(:fetch).with(123).and_return(fetched_show)

      expect(feed.show.title).to eq('Fetched Show')
      expect(feed.show.id).to eq(123)
    end

    it 'memoizes the fetched show' do
      feed = described_class.new(name: 'My Feed', show_id: 123)
      fetched_show = Ohdio::Show.new(id: 123, title: 'Fetched Show', type: 'balado', episodes: [])

      expect(Ohdio::Fetcher).to receive(:fetch).once.with(123).and_return(fetched_show)

      2.times { feed.show }
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
