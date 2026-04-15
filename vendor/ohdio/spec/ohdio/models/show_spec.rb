# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ohdio::Show do
  let(:episode) do
    Ohdio::Episode.new(
      id: 'abc123', title: 'Ep 1', description: 'Desc', published_at: '2026-01-01T00:00:00Z',
      duration: 1800, is_replay: false, url: '/ep/1'
    )
  end

  subject(:show) do
    described_class.new(
      id: 9887, title: 'La journée (est encore jeune)', description: 'Morning show',
      image_url: 'https://images.example.com/show.jpg', type: 'balado',
      page: 1, page_size: 25, total_episodes: 735, episodes: [episode]
    )
  end

  describe '#to_h' do
    it 'includes all show fields' do
      h = show.to_h
      expect(h[:id]).to eq(9887)
      expect(h[:title]).to eq('La journée (est encore jeune)')
      expect(h[:type]).to eq('balado')
      expect(h[:page]).to eq(1)
      expect(h[:total_episodes]).to eq(735)
    end

    it 'includes serialized episodes' do
      expect(show.to_h[:episodes].first[:id]).to eq('abc123')
    end

    it 'can skip segments and audio urls' do
      h = show.to_h(include_segments: false, include_audio_urls: false)

      expect(h[:episodes].first[:audio_url]).to be_nil
      expect(h[:episodes].first[:segments]).to eq([])
    end
  end

  describe '#to_json' do
    it 'round-trips through JSON' do
      parsed = JSON.parse(show.to_json)
      expect(parsed['id']).to eq(9887)
      expect(parsed['title']).to eq('La journée (est encore jeune)')
      expect(parsed['episodes'].first['id']).to eq('abc123')
    end
  end

  describe '#resolve!' do
    it 'hydrates missing fields from resolver on access' do
      lazy_show = described_class.new(id: 1, title: nil, episodes: [], resolver: lambda {
        described_class.new(id: 1, title: 'Resolved title', type: 'balado', episodes: [])
      })

      expect(lazy_show.title).to eq('Resolved title')
      expect(lazy_show.type).to eq('balado')
    end
  end
end
