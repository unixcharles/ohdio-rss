class Segment < ApplicationRecord
  belongs_to :episode
  belongs_to :audio_content, primary_key: :external_id, foreign_key: :audio_content_external_id, optional: true

  # The share URL's slug as words: ".../2503344/chronique-economique-pierre-yves-mcsween" =>
  # "chronique economique pierre yves mcsween". The slug names the recurring segment and its
  # contributor even when the day's title doesn't ("L'essence en folie?...", "...avec C. Hébert"),
  # so segment filters match against it as well as the title.
  def share_slug_words
    share_url.to_s.split("/").last.to_s.tr("-", " ")
  end
end
