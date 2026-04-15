class Segment < ApplicationRecord
  belongs_to :episode
  belongs_to :audio_content, primary_key: :external_id, foreign_key: :audio_content_external_id, optional: true
end
