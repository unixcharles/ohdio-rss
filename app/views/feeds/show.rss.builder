xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0", 'xmlns:itunes': "http://www.itunes.com/dtds/podcast-1.0.dtd",
                     'xmlns:content': "http://purl.org/rss/1.0/modules/content/" do
  xml.channel do
    xml.copyright("Radio-Canada")
    xml.title(@show.title || @feed.name)
    channel_description = plain_text_description(@show.description || @feed.name)
    xml.description(channel_description)
    xml.tag!("itunes:summary", channel_description)
    xml.tag!("itunes:subtitle", channel_description)
    xml.tag!("itunes:author", "Radio-Canada")
    xml.tag!("itunes:explicit", "clean")
    xml.tag!("itunes:category", text: "News")
    xml.link(@channel_link || @show.url || @base_url)
    if @show.image_url.present?
      image_url = rss_image_url(@show.image_url)
      xml.tag!("itunes:image", href: image_url)
      xml.image do
        xml.url(image_url)
        xml.title(@show.title || @feed.name)
        xml.link(@channel_link || @show.url || @base_url)
      end
    end
    xml.language("fr")
    xml.lastBuildDate(Time.current.rfc2822)

    @rss_items.each do |item|
      xml.item do
        xml.title(item[:title])
        if item[:description].present?
          xml.description(plain_text_description(item[:description]))
        end
        xml.pubDate(Time.parse(item[:published_at].to_s).rfc2822) if item[:published_at].present?
        xml.guid(item[:guid], isPermaLink: false)
        xml.tag!("itunes:author", "Radio-Canada")
        xml.tag!("itunes:explicit", "clean")
        xml.tag!("itunes:duration", item[:duration].to_i) if item[:duration].present?
        xml.link(item[:link]) if item[:link].present?
        enclosure_length = item[:duration].to_i
        enclosure_length = 1 if enclosure_length <= 0
        xml.enclosure(url: item[:enclosure_url], type: item[:enclosure_type], length: enclosure_length)
      end
    end
  end
end
