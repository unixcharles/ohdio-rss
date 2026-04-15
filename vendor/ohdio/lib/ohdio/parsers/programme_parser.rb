# frozen_string_literal: true

module Ohdio
  module Parsers
    class ProgrammeParser
      RC_BASE_URL = 'https://ici.radio-canada.ca/ohdio'
      DEFAULT_SEEK_TIME = 0

      def self.parse(data, programme_id:, type:, client:)
        new(client: client).parse(data, programme_id: programme_id, type: type)
      end

      def initialize(client:)
        @client = client
      end

      def parse(data, programme_id:, type:)
        type = type.to_sym

        if type == :audiobook
          parse_audiobook(data, programme_id: programme_id)
        else
          parse_programme(data, programme_id: programme_id, type: type)
        end
      end

      private

      def parse_programme(data, programme_id:, type:)
        prog = data.dig('data', 'programmeById')
        raise NotFoundError, "Programme #{programme_id} not found" unless found?(prog)

        header = prog['header'] || {}
        content = prog.dig('content', 'contentDetail') || {}
        items = content['items'] || []
        paged = content['pagedConfiguration'] || {}

        episodes = items.map { |item| parse_episode(item, type: type) }

        Show.new(
          id: programme_id,
          title: header['title'],
          description: header['summary'],
          image_url: header.dig('picture', 'pattern'),
          type: type.to_s,
          page: paged['pageNumber'] || 1,
          page_size: paged['pageSize'] || items.size,
          total_episodes: paged['totalNumberOfItems'] || items.size,
          episodes: episodes
        )
      end

      def parse_audiobook(data, programme_id:)
        book = data.dig('data', 'audioBookById')
        raise NotFoundError, "Audiobook #{programme_id} not found" unless found?(book)

        header = book['header'] || {}
        items = book.dig('content', 'contentDetail', 'items') || []

        episodes = items.each_with_index.map { |item, i| parse_audiobook_chapter(item, index: i) }

        Show.new(
          id: programme_id,
          title: header['title'],
          description: header['summary'],
          image_url: header.dig('picture', 'pattern'),
          type: 'audiobook',
          page: 1,
          page_size: episodes.size,
          total_episodes: episodes.size,
          episodes: episodes
        )
      end

      def parse_episode(item, type:)
        content_type_id = item.dig('playlistItemId', 'globalId2', 'contentType', 'id')
        playlist_item_id = item.dig('playlistItemId', 'globalId2', 'id')
        media_id = item.dig('playlistItemId', 'mediaId')

        segment_fetcher = build_segment_fetcher(type, content_type_id, playlist_item_id)
        audio_url_fetcher = build_audio_url_fetcher(media_id)

        Episode.new(
          id: playlist_item_id,
          title: item['title'],
          description: item['summary'],
          published_at: item['broadcastedFirstTimeAt'],
          duration: item.dig('duration', 'durationInSeconds'),
          is_replay: item['isBroadcastedReplay'],
          url: full_url(item['url']),
          media_id: media_id,
          segment_fetcher: segment_fetcher,
          audio_url_fetcher: audio_url_fetcher
        )
      end

      def parse_audiobook_chapter(item, index:)
        media_id = item.dig('playlistItemId', 'mediaId')

        Episode.new(
          id: "#{item.dig('playlistItemId', 'globalId2', 'id')}-#{index}",
          title: item['title'],
          description: item['summary'],
          published_at: item['broadcastedFirstTimeAt'],
          duration: item.dig('duration', 'durationInSeconds'),
          is_replay: false,
          url: full_url(item['url']),
          segment_fetcher: nil,
          audio_url_fetcher: build_audio_url_fetcher(media_id)
        )
      end

      def build_segment_fetcher(type, content_type_id, playlist_item_id)
        return nil unless type == :emission_premiere
        return nil unless content_type_id && playlist_item_id

        lambda {
          data = @client.get_playback_list(content_type_id, playlist_item_id)
          parse_segments(data)
        }
      end

      def build_audio_url_fetcher(media_id)
        return nil unless media_id

        -> { @client.get_media_url(media_id) }
      end

      def parse_segments(data)
        list = data.dig('data', 'playbackListByGlobalId')
        raise ApiError, 'Unexpected playback list response shape' unless list.is_a?(Hash)

        items = list['items'] || []
        items.filter_map { |item| parse_segment(item) }
      end

      def parse_segment(item)
        media = item['mediaPlaybackItem']
        return nil unless media

        media_id = media['mediaId']
        audio_url_fetcher = media_id ? -> { @client.get_media_url(media_id) } : nil

        Segment.new(
          title: item['title'],
          duration: item.dig('duration', 'durationInSeconds'),
          media_id: media_id,
          seek_time: media['mediaSeekTime'] || DEFAULT_SEEK_TIME,
          audio_url_fetcher: audio_url_fetcher
        )
      end

      def full_url(path)
        return nil if path.nil?

        path.start_with?('http') ? path : "#{RC_BASE_URL}#{path}"
      end

      def found?(prog)
        prog.is_a?(Hash) && !prog.empty? && !prog.dig('header', 'title').nil?
      end
    end
  end
end
