class Episode < ApplicationRecord
  belongs_to :show
  has_many :segments, dependent: :destroy

  after_commit :enqueue_trim_job, on: :create

  validates :ohdio_episode_id, presence: true

  private

  def enqueue_trim_job
    TrimShowEpisodesScheduler.enqueue(show_id)
  end
end
