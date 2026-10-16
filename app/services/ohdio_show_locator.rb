# Turns what a user pastes (an Ohdio show URL or a bare show ID) into a show that exists on Ohdio.
#
#   OhdioShowLocator.call("https://ici.radio-canada.ca/ohdio/premiere/emissions/1124/tout-un-matin")
#   # => #<Ohdio::Show id=1124 ...>
#
# Only show URLs are accepted: episode/segment URLs carry other numeric IDs (e.g.
# /emissions/tout-un-matin/segments/rattrapage/2503343/...) that are not show IDs.
class OhdioShowLocator
  class Error < StandardError; end

  SHOW_URL_ID = %r{/ohdio/(?:[a-z-]+/)?(?:balados|emissions|grandes-series|livres-audio)/(\d+)(?:[/?#]|\z)}

  def self.call(input)
    new(input).call
  end

  def self.show_id_from(input)
    value = input.to_s.strip
    return value.to_i if value.match?(/\A\d+\z/)

    value[SHOW_URL_ID, 1]&.to_i
  end

  def initialize(input)
    @input = input
  end

  def call
    show_id = self.class.show_id_from(@input)
    raise Error, "Paste an Ohdio show URL (like https://ici.radio-canada.ca/ohdio/premiere/emissions/1124/tout-un-matin) or a show ID." if show_id.nil?

    OhdioApiThrottle.call
    Ohdio::Fetcher.fetch(show_id)
  rescue Ohdio::NotFoundError, Ohdio::UnknownTypeError
    raise Error, "No Ohdio show found with ID #{show_id}."
  rescue Ohdio::Error => e
    raise Error, "Could not reach Ohdio to check show #{show_id}: #{e.message}"
  end
end
