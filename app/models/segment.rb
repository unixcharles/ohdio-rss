class Segment < ApplicationRecord
  belongs_to :episode
  belongs_to :medium, primary_key: :media_id, foreign_key: :media_id, optional: true
end
