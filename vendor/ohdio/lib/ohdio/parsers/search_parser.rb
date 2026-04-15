# frozen_string_literal: true

module Ohdio
  module Parsers
    class SearchParser
      RC_BASE_URL = 'https://ici.radio-canada.ca/ohdio'

      PRODUCT_KIND_BY_TYPENAME = {
        'CardBalado' => :balado,
        'CardEmission' => :emission,
        'CardGrandesSeries' => :grande_serie,
        'CardLivreAudio' => :audiobook
      }.freeze

      CONTENT_KIND_BY_TYPENAME = {
        'CardEpisodeBalado' => :episode,
        'CardEpisodeEmission' => :episode,
        'CardSegment' => :segment
      }.freeze

      def self.parse(data, build_product:, build_episode:, build_segment:)
        new(
          build_product: build_product,
          build_episode: build_episode,
          build_segment: build_segment
        ).parse(data)
      end

      def initialize(build_product:, build_episode:, build_segment:)
        @build_product = build_product
        @build_episode = build_episode
        @build_segment = build_segment
      end

      def parse(data)
        lineups = data.dig('data', 'searchPage', 'superLineup', 'lineups') || []

        lineups.flat_map do |lineup|
          (lineup['items'] || []).filter_map { |item| parse_item(item) }
        end
      end

      private

      def parse_item(item)
        typename = item['__typename']
        title = item['title']
        url = full_url(item['url'])

        if PRODUCT_KIND_BY_TYPENAME.key?(typename)
          parse_product(typename, title, url)
        elsif CONTENT_KIND_BY_TYPENAME.key?(typename)
          parse_content(typename, title, url)
        end
      end

      def parse_product(typename, title, url)
        kind = PRODUCT_KIND_BY_TYPENAME.fetch(typename)
        id = extract_product_id(url, kind)
        @build_product.call(kind, id, title, url)
      end

      def parse_content(typename, title, url)
        kind = CONTENT_KIND_BY_TYPENAME.fetch(typename)
        id = extract_content_id(url, kind)

        case kind
        when :episode then @build_episode.call(id, title, url)
        when :segment then @build_segment.call(id, title, url)
        end
      end

      def extract_product_id(url, kind)
        return nil if url.nil?

        case kind
        when :balado
          extract_first_group(url, %r{/balados/(\d+)})
        when :emission
          extract_first_group(url, %r{/emissions/(\d+)})
        when :grande_serie
          extract_first_group(url, %r{/grandes-series/(\d+)})
        when :audiobook
          extract_first_group(url, %r{/livres-audio/(\d+)})
        end
      end

      def extract_content_id(url, kind)
        return nil if url.nil?

        case kind
        when :episode
          extract_first_group(url, %r{/episodes/(\d+)}) || extract_first_group(url, %r{/balados/\d+/(\d+)})
        when :segment
          extract_first_group(url, %r{/segments/rattrapage/(\d+)})
        end
      end

      def extract_first_group(url, regex)
        match = regex.match(url)
        return nil unless match

        match[1].to_i
      end

      def full_url(path)
        return nil if path.nil?

        path.start_with?('http') ? path : "#{RC_BASE_URL}#{path}"
      end
    end
  end
end
