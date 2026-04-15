# frozen_string_literal: true

module Ohdio
  class Fetcher
    # Fetch a programme by numeric ID.
    #
    # @param id [Integer] Programme ID from the Radio-Canada Ohdio URL
    # @param type [Symbol, nil] One of :balado, :emission_premiere, :grande_serie, :audiobook.
    #   When nil, each type is tried in order until one succeeds.
    # @param page [Integer] Page number for pagination (audiobooks are always page 1)
    # @return [Ohdio::Show]
    # @raise [Ohdio::NotFoundError] if no programme is found for the given ID
    # @raise [Ohdio::UnknownTypeError] if type is nil and all type guesses fail
    # @raise [Ohdio::ApiError] on unexpected API or HTTP errors
    def self.fetch(id, type: nil, page: 1)
      new.fetch(id, type: type, page: page)
    end

    def initialize(client: Client.new)
      @client = client
    end

    def fetch(id, type: nil, page: 1)
      if type
        fetch_with_type(id, type.to_sym, page)
      else
        auto_detect(id, page)
      end
    end

    private

    def fetch_with_type(id, type, page)
      raise ApiError, 'Audiobooks do not support pagination beyond page 1' if type == :audiobook && page > 1

      data = @client.get_programme(type, id, page: page)
      Parsers::ProgrammeParser.parse(data, programme_id: id, type: type, client: @client)
    end

    def auto_detect(id, page)
      errors = []

      Graphql::TYPES.each do |type|
        return fetch_with_type(id, type, page)
      rescue NotFoundError => e
        errors << e.message
      end

      raise UnknownTypeError, "Could not determine type for programme #{id}. Tried: #{errors.join('; ')}"
    end
  end
end
