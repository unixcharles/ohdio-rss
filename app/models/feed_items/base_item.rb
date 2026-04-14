module FeedItems
  class BaseItem
    attr_reader :feed

    def initialize(feed:)
      @feed = feed
    end

    def segment?
      false
    end

    def episode?
      false
    end
  end
end
