class Feed < ApplicationRecord
  before_validation :ensure_uid, on: :create

  validates :name, presence: true
  validates :show_id, presence: true, numericality: { only_integer: true }
  validates :uid, presence: true, uniqueness: true

  def self.search_ohdio(query, filter: :all)
    normalized_query = query.to_s.strip
    return [] if normalized_query.blank?

    Ohdio::Searcher.search(normalized_query, filter: filter)
  end

  def show
    @show ||= Ohdio::Fetcher.fetch(show_id)
  end

  private

  def ensure_uid
    self.uid ||= SecureRandom.hex(16)
  end
end
