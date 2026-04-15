# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ohdio::Parsers::ProgrammeParser do
  let(:client) { instance_double(Ohdio::Client) }

  describe '.parse for balado' do
    let(:data) { fixture_json('balado_response') }
    subject(:show) { described_class.parse(data, programme_id: 9887, type: :balado, client: client) }

    it 'returns a Show' do
      expect(show).to be_a(Ohdio::Show)
    end

    it 'sets the correct show attributes' do
      expect(show.id).to eq(9887)
      expect(show.title).to eq('La journée (est encore jeune)')
      expect(show.type).to eq('balado')
    end

    it 'sets pagination attributes' do
      expect(show.page).to eq(1)
      expect(show.page_size).to eq(25)
      expect(show.total_episodes).to eq(735)
    end

    it 'parses episodes' do
      expect(show.episodes.size).to eq(2)
    end

    it 'parses episode attributes' do
      ep = show.episodes.first
      expect(ep.id).to eq('1163849')
      expect(ep.duration).to eq(1770)
      expect(ep.is_replay).to be(false)
      expect(ep.url).to start_with('https://ici.radio-canada.ca')
    end

    it 'does not fetch segments for balado episodes' do
      ep = show.episodes.first
      expect(client).not_to receive(:get_playback_list)
      expect(ep.segments).to eq([])
    end

    it 'lazily resolves audio_url via the media validation API' do
      ep = show.episodes.first
      expect(client).to receive(:get_media_url).with('10640801').and_return('https://example.com/audio.mp4')
      expect(ep.audio_url).to eq('https://example.com/audio.mp4')
    end

    it 'does not call get_media_url until audio_url is accessed' do
      allow(client).to receive(:get_media_url)
      show.episodes.first
      expect(client).not_to have_received(:get_media_url)
    end
  end

  describe '.parse for emission_premiere' do
    let(:data) { fixture_json('emission_premiere_response') }
    let(:playback_data) { fixture_json('playback_list_response') }
    subject(:show) { described_class.parse(data, programme_id: 1124, type: :emission_premiere, client: client) }

    it 'returns a Show with the correct type' do
      expect(show.type).to eq('emission_premiere')
      expect(show.title).to eq('Tout un matin')
    end

    it 'sets pagination from response' do
      expect(show.total_episodes).to eq(1434)
    end

    it 'lazily fetches segments on first access' do
      ep = show.episodes.first
      expect(client).to receive(:get_playback_list).with(18, '1020434').and_return(playback_data)
      segments = ep.segments
      expect(segments).not_to be_empty
    end

    it 'does not call the client until segments are accessed' do
      allow(client).to receive(:get_playback_list)
      show.episodes.first # parse but don't access segments
      expect(client).not_to have_received(:get_playback_list)
    end

    it 'memoizes the segment fetch' do
      ep = show.episodes.first
      allow(client).to receive(:get_playback_list).and_return(playback_data)
      ep.segments
      ep.segments
      expect(client).to have_received(:get_playback_list).once
    end

    it 'parses segments with correct attributes' do
      allow(client).to receive(:get_playback_list).and_return(playback_data)
      seg = show.episodes.first.segments.first
      expect(seg.title).to eq('Ouverture de l\'émission avec Patrick Masbourian et son équipe')
      expect(seg.duration).to eq(540)
      expect(seg.media_id).to eq('10640292')
      expect(seg.seek_time).to eq(0)
    end

    it 'wires audio_url_fetcher on segments' do
      allow(client).to receive(:get_playback_list).and_return(playback_data)
      allow(client).to receive(:get_media_url).with('10640292').and_return('https://example.com/broadcast.mp4')
      seg = show.episodes.first.segments.first
      expect(seg.audio_url).to eq('https://example.com/broadcast.mp4')
    end

    it 'episode audio_url is nil (segments carry the audio for emission_premiere)' do
      ep = show.episodes.first
      expect(ep.audio_url).to be_nil
    end

    it 'parses subsequent segments with incremented seek time' do
      allow(client).to receive(:get_playback_list).and_return(playback_data)
      segs = show.episodes.first.segments
      expect(segs[1].seek_time).to eq(540)
    end
  end

  describe '.parse for grande_serie' do
    let(:data) { fixture_json('grande_serie_response') }
    subject(:show) { described_class.parse(data, programme_id: 108, type: :grande_serie, client: client) }

    it 'returns a Show with the correct type' do
      expect(show.type).to eq('grande_serie')
    end

    it 'does not fetch segments' do
      ep = show.episodes.first
      expect(client).not_to receive(:get_playback_list)
      expect(ep.segments).to eq([])
    end
  end

  describe '.parse for audiobook' do
    let(:data) { fixture_json('audiobook_response') }
    subject(:show) { described_class.parse(data, programme_id: 42_418, type: :audiobook, client: client) }

    it 'returns a Show with the correct type' do
      expect(show.type).to eq('audiobook')
      expect(show.title).to eq('Du bon usage des étoiles')
    end

    it 'parses all chapters as episodes' do
      expect(show.episodes.size).to eq(7)
    end

    it 'gives each chapter a unique ID using its index' do
      ids = show.episodes.map(&:id)
      expect(ids.uniq.size).to eq(7)
    end

    it 'parses the first chapter title' do
      expect(show.episodes.first.title).to eq('Partie 1 - Argo Navis')
    end

    it 'reports page_size and total_episodes equal to chapter count' do
      expect(show.page_size).to eq(7)
      expect(show.total_episodes).to eq(7)
    end

    it 'does not fetch segments for audiobook chapters' do
      expect(client).not_to receive(:get_playback_list)
      show.episodes.each(&:segments)
    end

    it 'wires audio_url on each chapter' do
      allow(client).to receive(:get_media_url).and_return('https://example.com/chapter.mp4')
      expect(show.episodes.first.audio_url).to eq('https://example.com/chapter.mp4')
    end
  end

  describe 'segment parsing' do
    let(:data) { fixture_json('emission_premiere_response') }
    let(:playback_data) { fixture_json('playback_list_response') }
    subject(:show) { described_class.parse(data, programme_id: 1124, type: :emission_premiere, client: client) }

    it 'raises ApiError when playback list response is malformed' do
      malformed_data = { 'data' => {} }
      allow(client).to receive(:get_playback_list).and_return(malformed_data)
      allow(client).to receive(:get_media_url)
      ep = show.episodes.first
      expect { ep.segments }.to raise_error(Ohdio::ApiError, /playback list/)
    end

    it 'skips items without mediaPlaybackItem' do
      data_with_nil = Marshal.load(Marshal.dump(playback_data))
      data_with_nil['data']['playbackListByGlobalId']['items'].first['mediaPlaybackItem'] = nil
      allow(client).to receive(:get_playback_list).and_return(data_with_nil)
      segs = show.episodes.first.segments
      expect(segs.all? { |s| s.is_a?(Ohdio::Segment) }).to be(true)
    end
  end

  describe 'not found' do
    it 'raises NotFoundError when programmeById is nil' do
      data = fixture_json('not_found_response')
      expect do
        described_class.parse(data, programme_id: 99_999, type: :balado, client: client)
      end.to raise_error(Ohdio::NotFoundError, /99999/)
    end

    it 'raises NotFoundError when audioBookById is nil' do
      data = fixture_json('not_found_audiobook_response')
      expect do
        described_class.parse(data, programme_id: 99_999, type: :audiobook, client: client)
      end.to raise_error(Ohdio::NotFoundError, /99999/)
    end
  end
end
