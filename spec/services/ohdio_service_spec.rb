require "rails_helper"

RSpec.describe OhdioService do
  describe ".search_ohdio" do
    it "searches Ohdio with the provided query and filter" do
      show = Ohdio::Show.new(id: 777, title: "Cached Show", type: "balado")

      expect(Ohdio::Searcher).to receive(:search).once.with("science", filter: :balado).and_return([ show ])

      expect(described_class.search_ohdio("science", filter: :balado)).to eq([ show ])
    end

    it "returns an empty array for blank query" do
      expect(Ohdio::Searcher).not_to receive(:search)

      expect(described_class.search_ohdio("   ", filter: :all)).to eq([])
    end
  end
end
