require "rails_helper"

RSpec.describe Episode, type: :model do
  before do
    allow(TrimShowEpisodesScheduler).to receive(:enqueue)
  end

  it "enqueues trim job on create" do
    show = Show.create!(ohdio_id: 123, title: "Show")

    described_class.create!(show: show, ohdio_episode_id: "ep-1", position: 1)

    expect(TrimShowEpisodesScheduler).to have_received(:enqueue).with(show.id)
  end
end
