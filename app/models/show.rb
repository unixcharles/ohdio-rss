class Show < ApplicationRecord
  has_many :feeds, foreign_key: :show_id, primary_key: :ohdio_id, inverse_of: :show
  has_many :episodes, dependent: :destroy

  validates :ohdio_id, presence: true, uniqueness: true

  def emission_premiere?
    ohdio_type == "emission_premiere"
  end
end
