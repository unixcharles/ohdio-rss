# frozen_string_literal: true

module Ohdio
  module Graphql
    CONTEXT = 'web'

    TYPES = %i[balado emission_premiere grande_serie audiobook].freeze

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

    # Every query is sent as a full document via POST rather than by persisted query hash: the Ohdio
    # website moved to different queries and the hashes we relied on started failing with
    # PersistedQueryNotFound. Persisted hashes can be evicted at any time; query text keeps working.
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

    # Segments of an emission_premiere episode: exactly the fields ProgrammeParser#parse_segment reads.
    PLAYBACK_LIST_QUERY = <<~GRAPHQL
      query playbackListByGlobalId($params: PlaybackListByGlobalIdInput!) {
        playbackListByGlobalId(params: $params) {
          ... on PlaybackListEpisodePremiere {
            items {
              title
              duration { durationInSeconds }
              mediaPlaybackItem { mediaId mediaSeekTime }
            }
          }
        }
      }
    GRAPHQL

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

    def self.playback_variables(content_type_id, playlist_item_id)
      { contentTypeId: content_type_id, id: playlist_item_id }
    end
  end
end
