# frozen_string_literal: true

require 'json'

module Ohdio
  class Episode
    attr_reader :id, :media_id

    def initialize(id:, title: nil, description: nil, published_at: nil, duration: nil, is_replay: nil, url: nil,
                   media_id: nil, segment_fetcher: nil, audio_url_fetcher: nil, resolver: nil)
      @id = id
      @title = title
      @description = description
      @published_at = published_at
      @duration = duration
      @is_replay = is_replay
      @url = url
      @media_id = media_id
      @segment_fetcher = segment_fetcher
      @audio_url_fetcher = audio_url_fetcher
      @resolver = resolver
      @resolved = false
      @resolving = false
    end

    def title
      ensure_resolved(:@title)
      @title
    end

    def description
      ensure_resolved(:@description)
      @description
    end

    def published_at
      ensure_resolved(:@published_at)
      @published_at
    end

    def duration
      ensure_resolved(:@duration)
      @duration
    end

    def is_replay
      ensure_resolved(:@is_replay)
      @is_replay
    end

    def url
      ensure_resolved(:@url)
      @url
    end

    # Lazily fetches segments on first access. For emission_premiere this triggers
    # a second API call (playbackListByGlobalId). For other types returns [].
    def segments
      resolve! if @segments.nil? && @segment_fetcher.nil?
      @segments ||= @segment_fetcher ? @segment_fetcher.call : []
    end

    # Lazily resolves the direct audio download URL via the media validation API.
    # Returns nil for emission_premiere episodes (use segment#audio_url instead).
    def audio_url
      resolve! if @audio_url.nil? && @audio_url_fetcher.nil?
      @audio_url ||= @audio_url_fetcher ? @audio_url_fetcher.call : nil
    end

    def resolve!
      return self if @resolved || @resolver.nil? || @resolving

      @resolving = true
      resolved = @resolver.call
      hydrate_from(resolved) if resolved
      @resolved = true
      self
    ensure
      @resolving = false
    end

    def to_h(include_segments: true, include_audio_url: true, include_segment_audio_urls: include_audio_url)
      {
        id: id,
        title: title,
        description: description,
        published_at: published_at,
        duration: duration,
        is_replay: is_replay,
        url: url,
        audio_url: include_audio_url ? audio_url : nil,
        segments: if include_segments
                    segments.map do |segment|
                      segment.to_h(include_audio_url: include_segment_audio_urls)
                    end
                  else
                    []
                  end
      }
    end

    def to_json(*, **opts)
      JSON.generate(to_h(**opts))
    end

    private

    def ensure_resolved(ivar)
      return unless instance_variable_get(ivar).nil?

      resolve!
    end

    def hydrate_from(episode)
      @title = episode.title if @title.nil?
      @description = episode.description if @description.nil?
      @published_at = episode.published_at if @published_at.nil?
      @duration = episode.duration if @duration.nil?
      @is_replay = episode.is_replay if @is_replay.nil?
      @url = episode.url if @url.nil?
      @segments = episode.segments if @segments.nil? && episode.segments.any?
      @audio_url = episode.audio_url if @audio_url.nil? && !episode.audio_url.nil?
    end
  end
end
