require "cgi"

class TextEntityNormalizer
  def self.call(text)
    decoded = CGI.unescapeHTML(text.to_s)
    decoded = CGI.unescapeHTML(decoded)
    decoded = decoded.gsub(/&nbsp;?/i, "\u00A0")
    decoded = decoded.gsub(/&#160;|&#xA0;/i, "\u00A0")
    decoded.tr("\u00A0", " ").squish
  end
end
