# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ohdio::Episode do
  let(:segment) { Ohdio::Segment.new(title: 'Intro', duration: 60, media_id: '12345', seek_time: 0) }

  describe '#segments' do
    context 'without a segment_fetcher' do
      subject(:episode) do
        described_class.new(id: '1', title: 'Ep', description: nil,
                            published_at: nil, duration: 3600, is_replay: false, url: '/ep')
      end

      it 'returns an empty array' do
        expect(episode.segments).to eq([])
      end
    end

    context 'with a segment_fetcher' do
      let(:fetcher) { -> { [segment] } }
      subject(:episode) do
        described_class.new(id: '1', title: 'Ep', description: nil,
                            published_at: nil, duration: 3600, is_replay: false, url: '/ep',
                            segment_fetcher: fetcher)
      end

      it 'calls the fetcher and returns segments' do
        expect(episode.segments).to eq([segment])
      end

      it 'memoizes the result' do
        call_count = 0
        episode2 = described_class.new(id: '1', title: 'Ep', description: nil,
                                       published_at: nil, duration: 3600, is_replay: false, url: '/ep',
                                       segment_fetcher: lambda {
                                         call_count += 1
                                         [segment]
                                       })

        episode2.segments
        episode2.segments
        expect(call_count).to eq(1)
      end
    end
  end

  describe '#to_h' do
    subject(:episode) do
      described_class.new(
        id: 'abc', title: 'My Episode', description: '<p>Desc</p>',
        published_at: '2026-04-13T09:30:00.000Z', duration: 1800,
        is_replay: false, url: 'https://ici.radio-canada.ca/episode/abc'
      )
    end

    it 'includes all episode fields' do
      h = episode.to_h
      expect(h[:id]).to eq('abc')
      expect(h[:title]).to eq('My Episode')
      expect(h[:duration]).to eq(1800)
      expect(h[:is_replay]).to be(false)
      expect(h[:segments]).to eq([])
    end

    it 'can skip audio and segments' do
      h = episode.to_h(include_segments: false, include_audio_url: false)

      expect(h[:audio_url]).to be_nil
      expect(h[:segments]).to eq([])
    end
  end

  describe '#to_json' do
    subject(:episode) do
      described_class.new(
        id: 'abc', title: 'My Episode', description: nil,
        published_at: '2026-04-13T09:30:00.000Z', duration: 1800,
        is_replay: false, url: 'https://ici.radio-canada.ca/episode/abc',
        segment_fetcher: -> { [segment] }
      )
    end

    it 'round-trips through JSON' do
      parsed = JSON.parse(episode.to_json)
      expect(parsed['id']).to eq('abc')
      expect(parsed['segments'].first['title']).to eq('Intro')
    end
  end

  describe '#resolve!' do
    it 'hydrates missing fields on first access' do
      lazy_episode = described_class.new(id: '1', title: nil, resolver: lambda {
        described_class.new(id: '1', title: 'Resolved episode', description: 'Resolved desc')
      })

      expect(lazy_episode.title).to eq('Resolved episode')
      expect(lazy_episode.description).to eq('Resolved desc')
    end
  end
end
