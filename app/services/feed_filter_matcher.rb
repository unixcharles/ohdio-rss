class FeedFilterMatcher
  # Applies a set of include/exclude keyword filters to an ActiveRecord scope.
  #
  # `filters` is any enumerable of objects responding to #keyword and #include? - this works for
  # both a persisted FeedFilter association and the in-memory FeedFilter.new rows built for preview.
  #
  # Semantics: (any include-keyword match, or no include keywords at all) AND (no exclude-keyword match).
  # Keywords within the same group (include or exclude) are OR'd together.
  #
  # Matching is done in memory (the scope is already bounded to a feed's max_episodes worth of
  # records by the time this runs), then re-applied as a where(id:) so callers keep getting back
  # a chainable/queryable ActiveRecord::Relation instead of a plain array.
  def self.apply(scope, filters, columns: %i[title description])
    active = Array(filters).reject { |filter| filter.keyword.blank? }
    return scope if active.empty?

    includes, excludes = active.partition(&:include?)

    matching_ids = scope.select do |record|
      (includes.empty? || includes.any? { |filter| record_matches?(record, filter, columns) }) &&
        excludes.none? { |filter| record_matches?(record, filter, columns) }
    end.map(&:id)

    scope.where(id: matching_ids)
  end

  def self.record_matches?(record, filter, columns)
    keyword = normalize(filter.keyword.to_s.strip)
    columns.any? { |column| normalize(record.public_send(column).to_s).include?(keyword) }
  end
  private_class_method :record_matches?

  # Case-insensitive and accent-insensitive: "Hébert", "Hebert" and "hebert" all normalize alike.
  # NFKD splits accented letters into base char + combining mark, then \p{Mn} drops the marks.
  def self.normalize(string)
    string.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase
  end
  private_class_method :normalize
end
