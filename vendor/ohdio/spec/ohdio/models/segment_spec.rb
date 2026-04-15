# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ohdio::Segment do
  describe '#to_h' do
    it 'can skip audio url' do
      segment = described_class.new(
        title: 'Intro',
        duration: 60,
        media_id: '12345',
        seek_time: 0,
        audio_url_fetcher: -> { 'https://cdn.example.com/intro.mp3' }
      )

      expect(segment.to_h(include_audio_url: false)[:audio_url]).to be_nil
    end
  end

  describe '#resolve!' do
    it 'hydrates missing fields on access' do
      segment = described_class.new(media_id: nil, title: nil, resolver: lambda {
        described_class.new(media_id: '123', title: 'Resolved segment', duration: 30, seek_time: 0)
      })

      expect(segment.title).to eq('Resolved segment')
      expect(segment.media_id).to eq('123')
      expect(segment.duration).to eq(30)
    end
  end
end
