module ApplicationHelper
  EPISODE_PREFIX_REGEX = /\A\s*(?:episode|epi(?:sode)?|[eE]pisode|[Éé]pisode)\s+\d+\s*[:\-]\s*/i

  def sanitize_description(html)
    sanitize(
      html,
      tags: %w[p br ul ol li strong em b i a blockquote h1 h2 h3 h4 h5 h6],
      attributes: %w[href title]
    )
  end

  def plain_text_description(html)
    strip_tags(html.to_s).squish
  end

  def rss_image_url(url)
    url.to_s.gsub("{width}", "w_210").gsub("{ratio}", "1x1")
  end

  def display_episode_title(title)
    plain_title = TextEntityNormalizer.call(ActionController::Base.helpers.strip_tags(title.to_s))
    normalized = plain_title.gsub(EPISODE_PREFIX_REGEX, "").squish
    normalized.presence || plain_title
  end

  def display_ohdio_type(value)
    value.to_s.tr("_", " ").squish.titleize
  end

  def public_base_url
    configured = ENV["PUBLIC_BASE_URL"].to_s.strip
    base_url = configured.presence || request.base_url

    base_url.chomp("/")
  end

  def format_duration(seconds)
    return nil unless seconds.present? && seconds > 0

    total = seconds.to_i
    h = total / 3600
    m = (total % 3600) / 60
    s = total % 60
    h > 0 ? format("%d:%02d:%02d", h, m, s) : format("%d:%02d", m, s)
  end

  def public_rss_feed_url(feed)
    "#{public_base_url}#{rss_feed_path(uid: feed.uid, format: :rss)}"
  end
end
