class Medium < ApplicationRecord
  self.table_name = "media"

  has_many :segments, primary_key: :media_id, foreign_key: :media_id, inverse_of: :medium

  validates :media_id, presence: true, uniqueness: true
end
