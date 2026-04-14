require "uri"

class OhdioSegmentAudioUrlResolver
  MEDIA_URL_CACHE_TTL = 1.year
  MEDIA_URL_THROTTLE_SECONDS = 1.0

  def initialize(cache: Rails.cache)
    @cache = cache
  end

  def call(segments:)
    seen = {}

    Array(segments).filter_map do |segment|
      url = resolve_segment_url(segment)
      next if url.blank?

      normalized = normalize_url(url)
      next if normalized.blank?
      next if seen[normalized]

      seen[normalized] = true
      normalized
    end
  end

  private

  def resolve_segment_url(segment)
    media_id = segment.media_id

    if media_id.present?
      @cache.fetch([ "media-url", media_id ], expires_in: MEDIA_URL_CACHE_TTL) do
        sleep(MEDIA_URL_THROTTLE_SECONDS)
        segment.audio_url
      end
    else
      segment.audio_url
    end
  end

  def normalize_url(url)
    stripped = url.to_s.strip
    return nil if stripped.empty?

    uri = URI.parse(stripped)
    uri.fragment = nil
    uri.to_s
  rescue URI::InvalidURIError
    stripped
  end
end
