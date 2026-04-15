# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ohdio::Searcher do
  let(:client) { instance_double(Ohdio::Client) }
  let(:fetcher) { instance_double(Ohdio::Fetcher) }

  subject(:searcher) { described_class.new(client: client, fetcher: fetcher) }

  let(:search_payload) do
    {
      'data' => {
        'searchPage' => {
          'superLineup' => {
            'lineups' => [
              {
                'items' => [
                  { '__typename' => 'CardBalado', 'title' => 'Podcast A', 'url' => '/balados/10/podcast-a' },
                  { '__typename' => 'CardEmission', 'title' => 'Show B', 'url' => '/premiere/emissions/20/show-b' }
                ]
              },
              {
                'items' => [
                  { '__typename' => 'CardEpisodeBalado', 'title' => 'Episode C', 'url' => '/balados/10/301/episode-c' },
                  { '__typename' => 'CardSegment', 'title' => 'Segment D',
                    'url' => '/premiere/emissions/x/segments/rattrapage/401/segment-d' }
                ]
              }
            ]
          }
        }
      }
    }
  end

  describe '#search' do
    before do
      allow(client).to receive(:search_page).and_return(search_payload)
      allow(client).to receive(:get_episode_by_id).and_return(
        { 'data' => { 'episodeById' => { 'header' => { 'title' => 'Episode C', 'summary' => 'Desc',
                                                       'url' => '/x' } } } }
      )
      allow(client).to receive(:get_clip_by_id).and_return(
        { 'data' => { 'clipById' => { 'header' => { 'title' => 'Segment D', 'summary' => 'Desc', 'url' => '/y' } } } }
      )
      allow(fetcher).to receive(:fetch).and_return(
        Ohdio::Show.new(id: 10, title: 'Podcast A', type: 'balado', episodes: [])
      )
    end

    it 'returns mixed model objects' do
      results = searcher.search('podcast')
      expect(results).to include(an_instance_of(Ohdio::Show))
      expect(results).to include(an_instance_of(Ohdio::Episode))
      expect(results).to include(an_instance_of(Ohdio::Segment))
    end

    it 'filters to a specific product type' do
      results = searcher.search('podcast', filter: :balado)
      expect(results).to all(be_a(Ohdio::Show))
      expect(results.map(&:type)).to eq(['balado'])
    end

    it 'filters to contents only' do
      results = searcher.search('podcast', filter: :contents)
      expect(results).to all(satisfy { |item| item.is_a?(Ohdio::Episode) || item.is_a?(Ohdio::Segment) })
    end

    it 'raises UnknownTypeError for unsupported filters' do
      expect { searcher.search('podcast', filter: :unknown) }
        .to raise_error(Ohdio::UnknownTypeError, /Unknown search filter/)
    end

    it 'eagerly resolves models when requested' do
      show = Ohdio::Show.new(id: 10, title: nil, type: 'balado', episodes: [], resolver: lambda {
        Ohdio::Show.new(id: 10, title: 'Resolved', type: 'balado', episodes: [])
      })
      allow(searcher).to receive(:build_product_model).and_return(show)

      results = searcher.search('podcast', resolve: true)
      expect(results.first.title).to eq('Resolved')
    end

    it 'lazily resolves show episodes from fetcher' do
      resolved_show = Ohdio::Show.new(
        id: 10,
        title: 'Podcast A',
        type: 'balado',
        episodes: [Ohdio::Episode.new(id: 'ep-1', title: 'Episode 1')]
      )
      allow(fetcher).to receive(:fetch).with(10, type: :balado).and_return(resolved_show)

      show = searcher.search('podcast', filter: :balado).first
      expect(show.episodes.map(&:id)).to eq(['ep-1'])
    end
  end
end
