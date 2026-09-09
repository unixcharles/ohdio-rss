require 'rails_helper'

RSpec.describe FeedFilterMatcher do
  before do
    allow(FeedRefreshScheduler).to receive(:enqueue)
  end

  let(:show) { Show.create!(external_id: 950, title: 'Matcher Show') }

  def create_episode(title:, description: nil)
    show.episodes.create!(ohdio_episode_id: SecureRandom.hex(4), title: title, description: description)
  end

  it 'returns the scope unchanged when there are no filters' do
    create_episode(title: 'Simon raconte')

    result = described_class.apply(Episode.all, [])

    expect(result.pluck(:title)).to eq([ 'Simon raconte' ])
  end

  it 'includes only records matching an include keyword (OR within the group)' do
    create_episode(title: 'Simon raconte')
    create_episode(title: 'Tyler explique')
    create_episode(title: 'Frank arrive')

    filters = [
      FeedFilter.new(kind: 'episode', keyword: 'Simon', include: true),
      FeedFilter.new(kind: 'episode', keyword: 'Tyler', include: true)
    ]

    expect(described_class.apply(Episode.all, filters).pluck(:title)).to contain_exactly('Simon raconte', 'Tyler explique')
  end

  it 'excludes records matching an exclude keyword' do
    create_episode(title: 'Simon raconte')
    create_episode(title: 'Simon et Frank')

    filters = [ FeedFilter.new(kind: 'episode', keyword: 'Frank', include: false) ]

    expect(described_class.apply(Episode.all, filters).pluck(:title)).to eq([ 'Simon raconte' ])
  end

  it 'combines include and exclude filters' do
    create_episode(title: 'Simon raconte')
    create_episode(title: 'Simon et Frank')
    create_episode(title: 'Tyler explique')

    filters = [
      FeedFilter.new(kind: 'episode', keyword: 'Simon', include: true),
      FeedFilter.new(kind: 'episode', keyword: 'Frank', include: false)
    ]

    expect(described_class.apply(Episode.all, filters).pluck(:title)).to eq([ 'Simon raconte' ])
  end

  it 'matches case-insensitively' do
    create_episode(title: 'SIMON RACONTE')

    filters = [ FeedFilter.new(kind: 'episode', keyword: 'simon', include: true) ]

    expect(described_class.apply(Episode.all, filters).pluck(:title)).to eq([ 'SIMON RACONTE' ])
  end

  it 'matches accent-insensitively in both directions' do
    create_episode(title: 'Chronique de Chantal Hébert')
    create_episode(title: 'Entrevue avec Chantal Hebert')

    filters = [ FeedFilter.new(kind: 'episode', keyword: 'hebert', include: true) ]

    expect(described_class.apply(Episode.all, filters).pluck(:title)).to contain_exactly(
      'Chronique de Chantal Hébert', 'Entrevue avec Chantal Hebert'
    )

    accented = [ FeedFilter.new(kind: 'episode', keyword: 'Hébert', include: true) ]

    expect(described_class.apply(Episode.all, accented).pluck(:title)).to contain_exactly(
      'Chronique de Chantal Hébert', 'Entrevue avec Chantal Hebert'
    )
  end

  it 'matches against the given columns, including description' do
    create_episode(title: 'Episode 1', description: 'parle de politique')

    filters = [ FeedFilter.new(kind: 'episode', keyword: 'politique', include: true) ]

    expect(described_class.apply(Episode.all, filters, columns: %i[title description]).pluck(:title)).to eq([ 'Episode 1' ])
  end

  it 'ignores filter rows with a blank keyword' do
    create_episode(title: 'Simon raconte')

    filters = [ FeedFilter.new(kind: 'episode', keyword: '', include: true) ]

    expect(described_class.apply(Episode.all, filters).pluck(:title)).to eq([ 'Simon raconte' ])
  end
end
