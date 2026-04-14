require "rails_helper"

RSpec.describe TextEntityNormalizer do
  it "normalizes double-escaped nbsp entities" do
    input = "Chronique de Pierre-Yves McSween&amp;nbsp;:&amp;nbsp;Desjardins"

    expect(described_class.call(input)).to eq("Chronique de Pierre-Yves McSween : Desjardins")
  end
end
