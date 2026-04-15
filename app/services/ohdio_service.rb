class OhdioService
  def self.search_ohdio(query, filter: :all)
    normalized_query = query.to_s.strip
    return [] if normalized_query.blank?

    Ohdio::Searcher.search(normalized_query, filter: filter)
  end
end
