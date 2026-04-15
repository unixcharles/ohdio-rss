# frozen_string_literal: true

require 'json'

module Ohdio
  class Segment
    def initialize(title: nil, duration: nil, media_id: nil, seek_time: nil, audio_url_fetcher: nil, resolver: nil)
      @title = title
      @duration = duration
      @media_id = media_id
      @seek_time = seek_time
      @audio_url_fetcher = audio_url_fetcher
      @resolver = resolver
      @resolved = false
      @resolving = false
    end

    def title
      ensure_resolved(:@title)
      @title
    end

    def duration
      ensure_resolved(:@duration)
      @duration
    end

    def media_id
      ensure_resolved(:@media_id)
      @media_id
    end

    def seek_time
      ensure_resolved(:@seek_time)
      @seek_time
    end

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

    def to_h(include_audio_url: true)
      {
        title: title,
        duration: duration,
        media_id: media_id,
        seek_time: seek_time,
        audio_url: include_audio_url ? audio_url : nil
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

    def hydrate_from(segment)
      @title = segment.title if @title.nil?
      @duration = segment.duration if @duration.nil?
      @seek_time = segment.seek_time if @seek_time.nil?
      @media_id = segment.media_id if @media_id.nil?
      @audio_url = segment.audio_url if @audio_url.nil? && !segment.audio_url.nil?
    end
  end
end
