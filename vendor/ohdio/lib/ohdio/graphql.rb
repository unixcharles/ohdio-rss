# frozen_string_literal: true

require 'json'

module Ohdio
  module Graphql
    CONTEXT = 'web'

    TYPES = %i[balado emission_premiere grande_serie audiobook].freeze

    APQ_HASHES = {
      playback_list: 'ae95ebffe69f06d85a0f287931b61e3b7bfb7485f28d4d906c376be5f830b8c0'
    }.freeze

    # Selection shared by every programme query: exactly the fields ProgrammeParser reads.
    PROGRAMME_SELECTION = <<~GRAPHQL
      header { title summary picture { pattern } }
      content {
        contentDetail {
          items {
            ... on CardContentSummary {
              title
              summary
              url
              broadcastedFirstTimeAt
              isBroadcastedReplay
              duration { durationInSeconds }
              playlistItemId { mediaId globalId2 { id contentType { id } } }
            }
          }
          pagedConfiguration { pageNumber pageSize totalNumberOfItems }
        }
      }
    GRAPHQL

    # Programmes are fetched with a full query document via POST rather than by persisted query hash:
    # the Ohdio website moved to a different query and the programmeById/audioBookById hashes started
    # failing with PersistedQueryNotFound.
    PROGRAMME_QUERIES = {
      balado: <<~GRAPHQL,
        query programmeById($params: ProgrammeByIdInput!) {
          programmeById(params: $params) { ... on EmissionBalado { #{PROGRAMME_SELECTION} } }
        }
      GRAPHQL
      emission_premiere: <<~GRAPHQL,
        query programmeById($params: ProgrammeByIdInput!) {
          programmeById(params: $params) { ... on EmissionPremiere { #{PROGRAMME_SELECTION} } }
        }
      GRAPHQL
      grande_serie: <<~GRAPHQL,
        query programmeById($params: ProgrammeByIdInput!) {
          programmeById(params: $params) { ... on EmissionGrandesSeries { #{PROGRAMME_SELECTION} } }
        }
      GRAPHQL
      audiobook: <<~GRAPHQL
        query audioBookById($params: AudioBookByIdInput!) {
          audioBookById(params: $params) { ... on AudioBook { #{PROGRAMME_SELECTION} } }
        }
      GRAPHQL
    }.freeze

    FORCE_WITHOUT_CUE_SHEET = {
      balado: true,
      emission_premiere: false,
      grande_serie: true
    }.freeze

    def self.programme_query(type)
      PROGRAMME_QUERIES.fetch(type.to_sym) { raise UnknownTypeError, "Unknown programme type: #{type}" }
    end

    def self.programme_variables(type, id, page)
      return { context: CONTEXT, id: id } if type.to_sym == :audiobook

      {
        context: CONTEXT,
        forceWithoutCueSheet: FORCE_WITHOUT_CUE_SHEET[type.to_sym],
        id: id,
        pageNumber: page
      }
    end

    def self.playback_params(content_type_id, playlist_item_id)
      {
        'opname' => 'playbackListByGlobalId',
        'extensions' => JSON.generate({
                                        persistedQuery: { version: 1, sha256Hash: APQ_HASHES[:playback_list] }
                                      }),
        'variables' => JSON.generate({
                                       params: { contentTypeId: content_type_id, id: playlist_item_id }
                                     })
      }
    end
  end
end
