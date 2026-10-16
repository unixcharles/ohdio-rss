require "rails_helper"

RSpec.describe OhdioShowLocator do
  before { allow(OhdioApiThrottle).to receive(:call) }

  describe ".show_id_from" do
    {
      "1124" => 1124,
      " 1124 " => 1124,
      "https://ici.radio-canada.ca/ohdio/premiere/emissions/1124/tout-un-matin" => 1124,
      "https://ici.radio-canada.ca/ohdio/balados/14024/chantal-hebert-chroniques-et-entrevues" => 14_024,
      "https://ici.radio-canada.ca/ohdio/musique/emissions/3891/quandlejourseleve" => 3891,
      "https://ici.radio-canada.ca/ohdio/premiere/grandes-series/108/attendez" => 108,
      "https://ici.radio-canada.ca/ohdio/livres-audio/106010/mes-histoires" => 106_010,
      "https://ici.radio-canada.ca/ohdio/premiere/emissions/1124" => 1124
    }.each do |input, expected|
      it "reads #{expected} from #{input.inspect}" do
        expect(described_class.show_id_from(input)).to eq(expected)
      end
    end

    it "rejects episode and segment URLs, whose numbers are not show IDs" do
      url = "https://ici.radio-canada.ca/ohdio/premiere/emissions/tout-un-matin/segments/rattrapage/2503343/politique-federale-avec-chantal-hebert"

      expect(described_class.show_id_from(url)).to be_nil
    end
  end

  it "returns the show fetched from Ohdio" do
    show = Ohdio::Show.new(id: 2000, title: "Super Matin", type: "emission_premiere")
    allow(Ohdio::Fetcher).to receive(:fetch).with(2000).and_return(show)

    expect(described_class.call("https://ici.radio-canada.ca/ohdio/premiere/emissions/2000/super-matin")).to eq(show)
  end

  it "raises a friendly error when the show does not exist" do
    allow(Ohdio::Fetcher).to receive(:fetch).and_raise(Ohdio::UnknownTypeError, "nope")

    expect { described_class.call("99999") }.to raise_error(described_class::Error, /No Ohdio show found with ID 99999/)
  end

  it "raises a friendly error for input that is not a show URL or ID" do
    expect(Ohdio::Fetcher).not_to receive(:fetch)

    expect { described_class.call("Super Matin") }.to raise_error(described_class::Error, /Paste an Ohdio show URL/)
  end
end
