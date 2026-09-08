class FeedFilter < ApplicationRecord
  KINDS = %w[episode segment].freeze

  belongs_to :feed

  validates :kind, inclusion: { in: KINDS }
  validates :keyword, presence: true, length: { maximum: 100 }
end
