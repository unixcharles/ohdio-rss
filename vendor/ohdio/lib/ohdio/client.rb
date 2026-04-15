# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module Ohdio
  class Client
    BASE_URL = 'https://services.radio-canada.ca'
    GRAPHQL_PATH = '/bff/audio/graphql'
    MEDIA_PATH = '/media/validation/v2'

    HEADERS = {
      'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Content-Type' => 'application/json',
      'apollo-require-preflight' => 'true'
    }.freeze

    MEDIA_PARAMS = {
      'appCode' => 'medianet',
      'connectionType' => 'hd',
      'deviceType' => 'ipad',
      'multibitrate' => 'true',
      'output' => 'json',
      'tech' => 'progressive'
    }.freeze

    MAX_RETRIES = 3
    RETRY_BASE_DELAY = 0.5
    RETRY_MAX_DELAY = 8.0

    def get_programme(type, id, page: 1)
      params = Graphql.programme_params(type, id, page)
      get(GRAPHQL_PATH, params)
    end

    def get_playback_list(content_type_id, playlist_item_id)
      params = Graphql.playback_params(content_type_id, playlist_item_id)
      get(GRAPHQL_PATH, params)
    end

    def get_media_url(media_id)
      params = MEDIA_PARAMS.merge('idMedia' => media_id)
      data = get(MEDIA_PATH, params)
      url = data['url']
      raise ApiError, data['message'] || 'Media not found' if url.nil?

      url
    end

    def search_page(query:, num_products:, num_episodes:)
      gql = <<~GRAPHQL
        query SearchPage($params: SearchPageInput!) {
          searchPage(params: $params) {
            __typename
            ... on SearchPage {
              superLineup {
                lineups {
                  title
                  items {
                    __typename
                    ... on CardBalado {
                      title
                      url
                    }
                    ... on CardEmission {
                      title
                      url
                    }
                    ... on CardGrandesSeries {
                      title
                      url
                    }
                    ... on CardLivreAudio {
                      title
                      url
                    }
                    ... on CardEpisodeBalado {
                      title
                      url
                    }
                    ... on CardEpisodeEmission {
                      title
                      url
                    }
                    ... on CardSegment {
                      title
                      url
                    }
                  }
                }
              }
            }
          }
        }
      GRAPHQL

      post_graphql(gql, params: {
                     query: query,
                     numProducts: num_products,
                     numEpisodes: num_episodes
                   })
    end

    def get_episode_by_id(id:, force_without_cue_sheet: true, context: 'web')
      gql = <<~GRAPHQL
        query EpisodeById($params: EpisodeByIdInput!) {
          episodeById(params: $params) {
            __typename
            ... on EpisodeBalado {
              header {
                title
                summary
                url
              }
            }
            ... on EpisodePremiere {
              header {
                title
                summary
                url
              }
            }
            ... on EpisodeGrandesSeries {
              header {
                title
                summary
                url
              }
            }
            ... on EpisodeMusique {
              header {
                title
                summary
                url
              }
            }
          }
        }
      GRAPHQL

      post_graphql(gql, params: {
                     id: id,
                     context: context,
                     forceWithoutCueSheet: force_without_cue_sheet
                   })
    end

    def get_clip_by_id(id:, context: 'web')
      gql = <<~GRAPHQL
        query ClipById($params: ClipByIdInput!) {
          clipById(params: $params) {
            __typename
            ... on Clip {
              header {
                title
                summary
                url
              }
            }
            ... on ClipSegmentDeveloppe {
              header {
                title
                summary
                url
              }
            }
            ... on ClipSegmentNonDeveloppe {
              header {
                title
                summary
                url
              }
            }
          }
        }
      GRAPHQL

      post_graphql(gql, params: {
                     id: id,
                     context: context
                   })
    end

    private

    def get(path, params)
      uri = URI("#{BASE_URL}#{path}")
      uri.query = URI.encode_www_form(params)

      request = Net::HTTP::Get.new(uri)
      HEADERS.each { |k, v| request[k] = v }

      request_json_with_retries(uri, request)
    end

    def post_graphql(query, params: {})
      post(GRAPHQL_PATH, {
             query: query,
             variables: { params: params }
           })
    end

    def post(path, payload)
      uri = URI("#{BASE_URL}#{path}")

      request = Net::HTTP::Post.new(uri)
      HEADERS.each { |k, v| request[k] = v }
      request.body = JSON.generate(payload)

      request_json_with_retries(uri, request)
    end

    def request_json_with_retries(uri, request)
      retries = 0

      loop do
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        if response.code.to_i == 429 && retries < MAX_RETRIES
          sleep(retry_delay_seconds(response, retries))
          retries += 1
          next
        end

        raise ApiError, "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body)

        if data['errors']
          messages = data['errors'].map { |e| e['message'] }.join(', ')
          raise ApiError, messages
        end

        return data
      end
    end

    def retry_delay_seconds(response, retry_index)
      retry_after = response['Retry-After']
      return retry_after.to_f if retry_after && retry_after.to_f.positive?

      [RETRY_BASE_DELAY * (2**retry_index), RETRY_MAX_DELAY].min
    end
  end
end
