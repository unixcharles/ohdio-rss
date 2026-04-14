require "rails_helper"

RSpec.describe EpisodeQueryFilter do
  let(:show) { Show.create!(ohdio_id: 999, title: "Query Show") }

  def episode_ids_for(query)
    scope = show.episodes.order(:position)
    described_class.apply(scope, query).pluck(:ohdio_episode_id)
  end

  before do
    show.episodes.create!(ohdio_episode_id: "ep-1", title: "Simon et Tyler racontent", description: "discussion", position: 1)
    show.episodes.create!(ohdio_episode_id: "ep-2", title: "Tyler parle", description: "sans Frank", position: 2)
    show.episodes.create!(ohdio_episode_id: "ep-3", title: "Tyler et Frank", description: "duo", position: 3)
    show.episodes.create!(ohdio_episode_id: "ep-4", title: "Autre sujet", description: "Simon mentionne", position: 4)
  end

  it "matches plain string" do
    expect(episode_ids_for("Simon et Tyler")).to eq([ "ep-1" ])
  end

  it "supports OR" do
    expect(episode_ids_for("Simon OR Frank")).to eq([ "ep-1", "ep-2", "ep-3", "ep-4" ])
  end

  it "supports AND" do
    expect(episode_ids_for("Tyler AND Frank")).to eq([ "ep-2", "ep-3" ])
  end

  it "supports NOT" do
    expect(episode_ids_for("NOT Frank")).to eq([ "ep-1", "ep-4" ])
  end

  it "supports combined expressions with precedence" do
    expect(episode_ids_for("Simon OR Tyler AND NOT Frank")).to eq([ "ep-1", "ep-4" ])
  end
end
