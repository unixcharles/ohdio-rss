class AudioContent < ApplicationRecord
  has_many :episodes, primary_key: :external_id, foreign_key: :audio_content_external_id
  has_many :segments, primary_key: :external_id, foreign_key: :audio_content_external_id, inverse_of: :audio_content

  validates :external_id, presence: true, uniqueness: true
end
