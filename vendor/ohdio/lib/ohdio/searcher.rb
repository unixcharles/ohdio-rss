# frozen_string_literal: true

module Ohdio
  class Searcher
    DEFAULT_LIMIT = 20
    DEFAULT_CONTENT_LIMIT = 20
    MAX_QUERY_SIZE = 100
    QUERY_SANITIZER = /[^a-zA-Z0-9 àâäéèêëïîôùûüÿçÀÂÄÉÈÊËÏÎÔÙÛÜŸÇ&œ'’-]/

    FILTERS = {
      all: %i[balado emission grande_serie audiobook episode segment],
      products: %i[balado emission grande_serie audiobook],
      contents: %i[episode segment],
      balado: %i[balado],
      emission: %i[emission],
      grande_serie: %i[grande_serie],
      audiobook: %i[audiobook],
      episode: %i[episode],
      segment: %i[segment]
    }.freeze

    def self.search(query, filter: :all, resolve: false, limit: DEFAULT_LIMIT, content_limit: DEFAULT_CONTENT_LIMIT)
      new.search(query, filter: filter, resolve: resolve, limit: limit, content_limit: content_limit)
    end

    def self.search_podcasts_by_name(query, **opts)
      search(query, filter: :balado, **opts)
    end

    def initialize(client: Client.new, fetcher: nil)
      @client = client
      @fetcher = fetcher || Fetcher.new(client: client)
    end

    def search(query, filter: :all, resolve: false, limit: DEFAULT_LIMIT, content_limit: DEFAULT_CONTENT_LIMIT)
      data = @client.search_page(
        query: normalize_query(query),
        num_products: limit,
        num_episodes: content_limit
      )

      parsed = Parsers::SearchParser.parse(
        data,
        build_product: method(:build_product_model),
        build_episode: method(:build_episode_model),
        build_segment: method(:build_segment_model)
      )

      results = apply_filter(parsed, filter)
      resolve_results!(results) if resolve
      results
    end

    private

    def normalize_query(query)
      query.to_s.gsub(QUERY_SANITIZER, '').slice(0, MAX_QUERY_SIZE)
    end

    def apply_filter(results, filter)
      kinds = FILTERS.fetch(filter.to_sym) do
        raise UnknownTypeError, "Unknown search filter: #{filter}"
      end

      results.select { |result| kinds.include?(kind_for(result)) }
    end

    def kind_for(result)
      case result
      when Show
        result.type&.to_sym
      when Episode
        :episode
      when Segment
        :segment
      end
    end

    def build_product_model(kind, id, title, url)
      type = kind.to_s
      Show.new(
        id: id,
        title: title,
        type: type,
        url: url,
        episodes: nil,
        resolver: product_resolver(id, kind)
      )
    end

    def build_episode_model(id, title, url)
      Episode.new(
        id: id,
        title: title,
        url: url,
        resolver: episode_resolver(id)
      )
    end

    def build_segment_model(id, title, _url)
      Segment.new(
        media_id: nil,
        title: title,
        seek_time: 0,
        resolver: segment_resolver(id)
      )
    end

    def resolve_results!(results)
      results.each do |result|
        result.resolve! if result.respond_to?(:resolve!)
      rescue NotFoundError, ApiError
        next
      end
    end

    def product_resolver(id, kind)
      return nil if id.nil?

      lambda do
        if kind == :emission
          @fetcher.fetch(id)
        else
          @fetcher.fetch(id, type: kind)
        end
      end
    end

    def episode_resolver(id)
      return nil if id.nil?

      lambda do
        data = @client.get_episode_by_id(id: id, force_without_cue_sheet: true)
        node = data.dig('data', 'episodeById') || {}
        header = node['header'] || {}

        Episode.new(
          id: id,
          title: header['title'],
          description: header['summary'],
          url: full_url(header['url'])
        )
      end
    end

    def segment_resolver(id)
      return nil if id.nil?

      lambda do
        data = @client.get_clip_by_id(id: id)
        node = data.dig('data', 'clipById') || {}
        header = node['header'] || {}

        Segment.new(
          title: header['title'],
          media_id: nil,
          duration: nil,
          seek_time: 0
        )
      end
    end

    def full_url(path)
      return nil if path.nil?

      path.start_with?('http') ? path : "https://ici.radio-canada.ca/ohdio#{path}"
    end
  end
end
