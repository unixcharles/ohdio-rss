# frozen_string_literal: true

require 'json'

module Ohdio
  module Graphql
    CONTEXT = 'web'
    API_VERSION = 1

    TYPES = %i[balado emission_premiere grande_serie audiobook].freeze

    APQ_HASHES = {
      balado: '3b505d1f3b3935981802bccab9c9ee63bbf6c5c55a0b996287fb789e1a90e660',
      emission_premiere: '7e961f5b1091589230b1f56ca6be609d26e5c475934235103afb55589a397e0c',
      grande_serie: 'c09912897e8cd67f8cacc65842a16d65b10829f06cdedfedc50bdeb0acb9989c',
      audiobook: 'a676e346c1993bbfcf6924eac2f3e3d45ad3055721c6949b74fbd0d33a505a59',
      playback_list: 'ae95ebffe69f06d85a0f287931b61e3b7bfb7485f28d4d906c376be5f830b8c0'
    }.freeze

    FORCE_WITHOUT_CUE_SHEET = {
      balado: true,
      emission_premiere: false,
      grande_serie: true
    }.freeze

    def self.programme_params(type, id, page)
      type = type.to_sym
      raise UnknownTypeError, "Unknown programme type: #{type}" unless TYPES.include?(type)

      if type == :audiobook
        audiobook_params(id)
      else
        programme_by_id_params(type, id, page)
      end
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

    private_class_method def self.programme_by_id_params(type, id, page)
      {
        'opname' => 'programmeById',
        'extensions' => JSON.generate({
                                        persistedQuery: { version: API_VERSION, sha256Hash: APQ_HASHES[type] }
                                      }),
        'variables' => JSON.generate({
                                       params: {
                                         context: CONTEXT,
                                         forceWithoutCueSheet: FORCE_WITHOUT_CUE_SHEET[type],
                                         id: id,
                                         pageNumber: page
                                       }
                                     })
      }
    end

    private_class_method def self.audiobook_params(id)
      {
        'opname' => 'audioBookById',
        'extensions' => JSON.generate({
                                        persistedQuery: { version: API_VERSION, sha256Hash: APQ_HASHES[:audiobook] }
                                      }),
        'variables' => JSON.generate({
                                       params: { context: CONTEXT, id: id }
                                     })
      }
    end
  end
end
