# frozen_string_literal: true

require 'json'

module Ohdio
  class Show
    attr_reader :id

    def initialize(id:, title: nil, description: nil, image_url: nil, type: nil,
                   page: nil, page_size: nil, total_episodes: nil, episodes: nil, url: nil, resolver: nil)
      @id = id
      @title = title
      @description = description
      @image_url = image_url
      @type = type
      @page = page
      @page_size = page_size
      @total_episodes = total_episodes
      @episodes = episodes
      @url = url
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

    def image_url
      ensure_resolved(:@image_url)
      @image_url
    end

    def type
      ensure_resolved(:@type)
      @type
    end

    def page
      ensure_resolved(:@page)
      @page
    end

    def page_size
      ensure_resolved(:@page_size)
      @page_size
    end

    def total_episodes
      ensure_resolved(:@total_episodes)
      @total_episodes
    end

    def episodes
      ensure_resolved(:@episodes)
      @episodes || []
    end

    def url
      ensure_resolved(:@url)
      @url
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

    def to_h(include_episodes: true, include_segments: true, include_audio_urls: true,
             include_segment_audio_urls: include_audio_urls)
      {
        id: id,
        title: title,
        description: description,
        image_url: image_url,
        type: type,
        page: page,
        page_size: page_size,
        total_episodes: total_episodes,
        url: url,
        episodes: if include_episodes
                    episodes.map do |episode|
                      episode.to_h(
                        include_segments: include_segments,
                        include_audio_url: include_audio_urls,
                        include_segment_audio_urls: include_segment_audio_urls
                      )
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

    def hydrate_from(show)
      @title = show.title if @title.nil?
      @description = show.description if @description.nil?
      @image_url = show.image_url if @image_url.nil?
      @type = show.type if @type.nil?
      @page = show.page if @page.nil?
      @page_size = show.page_size if @page_size.nil?
      @total_episodes = show.total_episodes if @total_episodes.nil?
      @episodes = show.episodes if @episodes.nil?
      @url = show.url if @url.nil? && show.respond_to?(:url)
    end
  end
end
