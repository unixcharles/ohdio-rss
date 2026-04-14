require "rails_helper"

RSpec.describe OhdioSegmentAudioUrlResolver do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  it "caches url resolution by media id" do
    segment_one = instance_double(
      Ohdio::Segment,
      media_id: "m1",
      audio_url: "https://cdn.example.com/a.mp3"
    )
    segment_two = instance_double(
      Ohdio::Segment,
      media_id: "m1",
      audio_url: "https://cdn.example.com/a.mp3"
    )

    expect(segment_one).to receive(:audio_url).once.and_return("https://cdn.example.com/a.mp3")
    expect(segment_two).not_to receive(:audio_url)

    urls = described_class.new(cache: cache).call(segments: [ segment_one, segment_two ])

    expect(urls).to eq([ "https://cdn.example.com/a.mp3" ])
  end

  it "dedupes by normalized url and preserves order" do
    segment_one = instance_double(Ohdio::Segment, media_id: nil, audio_url: "https://cdn.example.com/a.mp3#t=0,30")
    segment_two = instance_double(Ohdio::Segment, media_id: nil, audio_url: "https://cdn.example.com/b.mp3")
    segment_three = instance_double(Ohdio::Segment, media_id: nil, audio_url: "https://cdn.example.com/a.mp3#t=30,60")

    urls = described_class.new(cache: cache).call(segments: [ segment_one, segment_two, segment_three ])

    expect(urls).to eq([
      "https://cdn.example.com/a.mp3",
      "https://cdn.example.com/b.mp3"
    ])
  end

  it "skips blank urls" do
    segment_one = instance_double(Ohdio::Segment, media_id: nil, audio_url: nil)
    segment_two = instance_double(Ohdio::Segment, media_id: nil, audio_url: "")
    segment_three = instance_double(Ohdio::Segment, media_id: nil, audio_url: "https://cdn.example.com/c.mp3")

    urls = described_class.new(cache: cache).call(segments: [ segment_one, segment_two, segment_three ])

    expect(urls).to eq([ "https://cdn.example.com/c.mp3" ])
  end
end
