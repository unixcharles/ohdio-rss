class Show < ApplicationRecord
  has_many :feeds, foreign_key: :show_external_id, primary_key: :external_id, inverse_of: :show
  has_many :episodes, dependent: :destroy

  validates :external_id, presence: true, uniqueness: true

  def emission_premiere?
    ohdio_type == "emission_premiere"
  end

  def chronological_order?
    ohdio_type.in?(%w[audiobook grande_serie])
  end
end
