class FeedFilterReplacer
  # Replaces all of a feed's filter rows of one kind ("episode" or "segment") with the given rows.
  #
  # Rows are plain hashes shaped like the form submission (keyword:, include:) - while the user is
  # adding/removing/toggling rows in the UI, they only ever exist as such hashes, never touching
  # the database. This is only called at save time, and always fully replaces the existing set:
  # FeedFilter rows have no identity anything else depends on, so there's no need to diff which
  # row was edited vs added vs removed.
  def self.call(feed:, kind:, rows:)
    new(feed: feed, kind: kind, rows: rows).call
  end

  def initialize(feed:, kind:, rows:)
    @feed = feed
    @kind = kind
    @rows = rows
  end

  def call
    feed.feed_filters.where(kind: kind).destroy_all

    Array(rows).each do |row|
      keyword = row[:keyword] || row["keyword"]
      next if keyword.blank?

      include_value = row.key?(:include) ? row[:include] : row["include"]
      feed.feed_filters.create!(kind: kind, keyword: keyword.to_s.strip, include: include_value)
    end
  end

  private

  attr_reader :feed, :kind, :rows
end
