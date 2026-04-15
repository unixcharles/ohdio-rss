# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ohdio::Client do
  subject(:client) { described_class.new }

  describe '#get_programme' do
    context 'when the request succeeds',
            vcr: { cassette_name: 'programmes/balado_9887' } do
      it 'returns parsed JSON data' do
        data = client.get_programme(:balado, 9887)
        expect(data.dig('data', 'programmeById', 'header', 'title')).to eq('La journée (est encore jeune)')
      end

      it 'sends the required headers' do
        client.get_programme(:balado, 9887)
        expect(WebMock).to have_requested(:get, /graphql/).with(
          headers: {
            'Content-Type' => 'application/json',
            'apollo-require-preflight' => 'true'
          }
        )
      end
    end

    context 'when the API returns an errors array' do
      it 'raises ApiError' do
        body = { 'errors' => [{ 'message' => 'Invalid AST Node' }] }.to_json
        stub_request(:get, /graphql/).to_return(status: 200, body: body)
        expect { client.get_programme(:balado, 9887) }.to raise_error(Ohdio::ApiError, /Invalid AST Node/)
      end
    end

    context 'when the HTTP response is a 500' do
      it 'raises ApiError with the status code' do
        stub_request(:get, /graphql/).to_return(status: 500, body: '')
        expect { client.get_programme(:balado, 9887) }.to raise_error(Ohdio::ApiError, /HTTP 500/)
      end
    end

    context 'when the HTTP response is a 404' do
      it 'raises ApiError with the status code' do
        stub_request(:get, /graphql/).to_return(status: 404, body: '')
        expect { client.get_programme(:balado, 9887) }.to raise_error(Ohdio::ApiError, /HTTP 404/)
      end
    end

    context 'when the server responds with 429 then succeeds' do
      it 'retries and returns parsed data' do
        success_body = {
          'data' => {
            'programmeById' => {
              'header' => { 'title' => 'Recovered' }
            }
          }
        }.to_json

        stub_request(:get, /graphql/)
          .to_return({ status: 429, body: '' }, { status: 200, body: success_body })

        allow(client).to receive(:sleep)

        data = client.get_programme(:balado, 9887)
        expect(data.dig('data', 'programmeById', 'header', 'title')).to eq('Recovered')
        expect(client).to have_received(:sleep).once
      end
    end

    context 'when the server keeps responding with 429' do
      it 'raises ApiError after retries' do
        stub_request(:get, /graphql/).to_return(status: 429, body: '')
        allow(client).to receive(:sleep)

        expect { client.get_programme(:balado, 9887) }.to raise_error(Ohdio::ApiError, /HTTP 429/)
      end
    end
  end

  describe '#get_playback_list' do
    context 'when the request succeeds',
            vcr: { cassette_name: 'playback/episode_1020434' } do
      it 'returns parsed JSON data' do
        data = client.get_playback_list(18, '1020434')
        items = data.dig('data', 'playbackListByGlobalId', 'items')
        expect(items).not_to be_empty
      end
    end

    context 'when the API returns errors' do
      it 'raises ApiError' do
        body = { 'errors' => [{ 'message' => 'Error' }] }.to_json
        stub_request(:get, /graphql/).to_return(status: 200, body: body)
        expect { client.get_playback_list(18, '1020434') }.to raise_error(Ohdio::ApiError)
      end
    end
  end

  describe '#get_media_url' do
    context 'when the media exists',
            vcr: { cassette_name: 'media/10640801' } do
      it 'returns the download URL' do
        url = client.get_media_url('10640801')
        expect(url).to start_with('https://')
        expect(url).to include('.mp4')
      end
    end

    context 'when the media is not found',
            vcr: { cassette_name: 'errors/media_not_found' } do
      it 'raises ApiError' do
        expect { client.get_media_url('0') }.to raise_error(Ohdio::ApiError, /trouv/)
      end
    end

    context 'when the HTTP request fails' do
      it 'raises ApiError' do
        stub_request(:get, %r{media/validation}).to_return(status: 500, body: '')
        expect { client.get_media_url('10640801') }.to raise_error(Ohdio::ApiError, /HTTP 500/)
      end
    end
  end

  describe '#search_page' do
    it 'posts a GraphQL request and returns parsed data' do
      body = {
        'data' => {
          'searchPage' => {
            'superLineup' => {
              'lineups' => [{ 'items' => [{ '__typename' => 'CardBalado', 'title' => 'A', 'url' => '/balados/1/a' }] }]
            }
          }
        }
      }.to_json

      stub_request(:post, %r{/bff/audio/graphql}).to_return(status: 200, body: body)

      data = client.search_page(query: 'balado', num_products: 5, num_episodes: 5)
      expect(data.dig('data', 'searchPage', 'superLineup', 'lineups', 0, 'items', 0, 'title')).to eq('A')
      expect(WebMock).to have_requested(:post, %r{/bff/audio/graphql})
    end
  end

  describe '#get_episode_by_id' do
    it 'posts the EpisodeById query' do
      body = {
        'data' => {
          'episodeById' => {
            '__typename' => 'EpisodeBalado',
            'header' => { 'title' => 'Episode' }
          }
        }
      }.to_json

      stub_request(:post, %r{/bff/audio/graphql}).to_return(status: 200, body: body)

      data = client.get_episode_by_id(id: 123)
      expect(data.dig('data', 'episodeById', 'header', 'title')).to eq('Episode')
      expect(WebMock).to have_requested(:post, %r{/bff/audio/graphql})
    end
  end

  describe '#get_clip_by_id' do
    it 'posts the ClipById query' do
      body = {
        'data' => {
          'clipById' => {
            '__typename' => 'ClipSegmentNonDeveloppe',
            'header' => { 'title' => 'Segment' }
          }
        }
      }.to_json

      stub_request(:post, %r{/bff/audio/graphql}).to_return(status: 200, body: body)

      data = client.get_clip_by_id(id: 456)
      expect(data.dig('data', 'clipById', 'header', 'title')).to eq('Segment')
      expect(WebMock).to have_requested(:post, %r{/bff/audio/graphql})
    end
  end
end
