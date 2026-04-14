module ApplicationHelper
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
end
