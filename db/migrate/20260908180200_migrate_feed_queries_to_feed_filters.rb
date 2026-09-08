class MigrateFeedQueriesToFeedFilters < ActiveRecord::Migration[8.1]
  OPERATOR_REGEX = /\b(?:AND|OR|NOT)\b/i

  class MigrationFeed < ActiveRecord::Base
    self.table_name = "feeds"
  end

  class MigrationFeedFilter < ActiveRecord::Base
    self.table_name = "feed_filters"
  end

  def up
    MigrationFeed.reset_column_information
    MigrationFeedFilter.reset_column_information

    MigrationFeed.find_each do |feed|
      convert(feed, feed.episode_query, kind: "episode")
      convert(feed, feed.segment_query, kind: "segment")
    end
  end

  def down
    MigrationFeedFilter.delete_all
  end

  private

  def convert(feed, query, kind:)
    normalized = query.to_s.strip
    return if normalized.blank?

    tokens = tokenize(normalized)

    if tokens.any? { |token| token[:type] == :operator && token[:value] == "AND" }
      puts "  [feed_filters migration] Skipping #{kind} query for feed ##{feed.id} (#{feed.name}) " \
           "- uses AND, can't convert automatically: #{normalized.inspect}"
      return
    end

    tokens.each_with_index do |token, index|
      next unless token[:type] == :term

      preceding = tokens[index - 1] if index.positive?
      excluded = preceding && preceding[:type] == :operator && preceding[:value] == "NOT"

      MigrationFeedFilter.create!(
        feed_id: feed.id,
        kind: kind,
        keyword: token[:value],
        include: !excluded
      )
    end
  end

  def tokenize(query)
    tokens = []
    cursor = 0

    query.to_enum(:scan, OPERATOR_REGEX).map { Regexp.last_match }.each do |match|
      leading = query[cursor...match.begin(0)].to_s.strip
      tokens << { type: :term, value: leading } if leading.present?
      tokens << { type: :operator, value: match[0].upcase }
      cursor = match.end(0)
    end

    trailing = query[cursor..].to_s.strip
    tokens << { type: :term, value: trailing } if trailing.present?
    tokens
  end
end
