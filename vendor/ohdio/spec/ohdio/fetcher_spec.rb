# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ohdio::Fetcher do
  describe '.fetch' do
    context 'balado: La journée (est encore jeune) — ID 9887' do
      it 'returns a Show with correct title and type',
         vcr: { cassette_name: 'programmes/balado_9887' } do
        show = described_class.fetch(9887, type: :balado)
        expect(show).to be_a(Ohdio::Show)
        expect(show.title).to eq('La journée (est encore jeune)')
        expect(show.type).to eq('balado')
      end

      it 'returns episodes',
         vcr: { cassette_name: 'programmes/balado_9887' } do
        show = described_class.fetch(9887, type: :balado)
        expect(show.episodes).not_to be_empty
      end

      it 'serializes to JSON including audio_url',
         vcr: { cassette_name: 'fetcher/balado_9887_to_json' } do
        show = described_class.fetch(9887, type: :balado)
        parsed = JSON.parse(show.to_json)
        expect(parsed['title']).to eq('La journée (est encore jeune)')
        expect(parsed['type']).to eq('balado')
        expect(parsed['episodes'].first['audio_url']).to start_with('https://')
        expect(parsed['episodes'].first['segments']).to eq([])
      end
    end

    context 'emission_premiere: Tout un matin — ID 1124' do
      it 'returns a Show with correct title and type',
         vcr: { cassette_name: 'programmes/emission_premiere_1124' } do
        show = described_class.fetch(1124, type: :emission_premiere)
        expect(show.title).to eq('Tout un matin')
        expect(show.type).to eq('emission_premiere')
        expect(show.total_episodes).to eq(1434)
      end

      it 'provides segments on demand for the first episode',
         vcr: { cassette_name: 'fetcher/emission_1124_with_segments' } do
        show = described_class.fetch(1124, type: :emission_premiere)
        segments = show.episodes.first.segments
        expect(segments).not_to be_empty
        expect(segments.first).to be_a(Ohdio::Segment)
        expect(segments.first.seek_time).to eq(0)
        expect(segments[1].seek_time).to eq(540)
      end

      it 'episode audio_url is nil — audio lives in segments',
         vcr: { cassette_name: 'programmes/emission_premiere_1124' } do
        show = described_class.fetch(1124, type: :emission_premiere)
        expect(show.episodes.first.audio_url).to be_nil
      end

      it 'segments carry audio_url resolved via media validation',
         vcr: { cassette_name: 'fetcher/emission_1124_with_segments_and_audio' } do
        show = described_class.fetch(1124, type: :emission_premiere)
        seg = show.episodes.first.segments.first
        expect(seg.title).to include('Ouverture')
        expect(seg.media_id).to eq('10640292')
        expect(seg.audio_url).to start_with('https://')
        expect(seg.audio_url).to include('.mp4')
      end
    end

    context 'grande_serie: Attendez qu\'on se souvienne — ID 108' do
      it 'returns a Show with correct type and empty segments',
         vcr: { cassette_name: 'programmes/grande_serie_108' } do
        show = described_class.fetch(108, type: :grande_serie)
        expect(show.type).to eq('grande_serie')
        expect(show.episodes.first.segments).to eq([])
      end
    end

    context 'audiobook: Du bon usage des étoiles — ID 42418' do
      it 'returns all chapters as episodes with correct type and title',
         vcr: { cassette_name: 'programmes/audiobook_42418' } do
        show = described_class.fetch(42_418, type: :audiobook)
        expect(show.title).to eq('Du bon usage des étoiles')
        expect(show.type).to eq('audiobook')
        expect(show.episodes.size).to eq(7)
        expect(show.episodes.first.title).to eq('Partie 1 - Argo Navis')
      end

      it 'raises ApiError when paginating beyond page 1' do
        expect do
          described_class.fetch(42_418, type: :audiobook, page: 2)
        end.to raise_error(Ohdio::ApiError, /pagination/)
      end
    end

    context 'pagination' do
      it 'passes the page number to the API',
         vcr: { cassette_name: 'programmes/emission_premiere_1124_page_2' } do
        show = described_class.fetch(1124, type: :emission_premiere, page: 2)
        expect(show).to be_a(Ohdio::Show)
      end
    end

    context 'auto-detect type' do
      it 'returns on the first matching type (balado)',
         vcr: { cassette_name: 'fetcher/auto_detect_balado' } do
        show = described_class.fetch(9887)
        expect(show.type).to eq('balado')
      end

      it 'falls through to the matching type when earlier guesses return not-found',
         vcr: { cassette_name: 'fetcher/auto_detect_emission' } do
        show = described_class.fetch(1124)
        expect(show.type).to eq('emission_premiere')
      end

      it 'raises UnknownTypeError when all types return not-found',
         vcr: { cassette_name: 'fetcher/auto_detect_all_not_found' } do
        expect do
          described_class.fetch(99_999)
        end.to raise_error(Ohdio::UnknownTypeError, /99999/)
      end
    end

    context 'sad paths' do
      it 'raises NotFoundError for an unknown ID with explicit type',
         vcr: { cassette_name: 'errors/not_found_balado' } do
        expect do
          described_class.fetch(99_999, type: :balado)
        end.to raise_error(Ohdio::NotFoundError)
      end

      it 'raises UnknownTypeError for an invalid type symbol' do
        expect do
          described_class.fetch(1234, type: :invalid_type)
        end.to raise_error(Ohdio::UnknownTypeError, /invalid_type/)
      end

      it 'raises ApiError when the API returns an error payload' do
        body = { 'errors' => [{ 'message' => 'Error' }] }.to_json
        stub_request(:get, /graphql/).to_return(status: 200, body: body)
        expect do
          described_class.fetch(9887, type: :balado)
        end.to raise_error(Ohdio::ApiError)
      end

      it 'raises ApiError on HTTP 500' do
        stub_request(:get, /graphql/).to_return(status: 500, body: '')
        expect do
          described_class.fetch(9887, type: :balado)
        end.to raise_error(Ohdio::ApiError, /HTTP 500/)
      end
    end
  end
end
