require "rails_helper"
require "tmpdir"
require "tempfile"

RSpec.describe RemoteAudioFileDownloader do
  it "downloads unique normalized urls in first-seen order and reuses cached files" do
    Dir.mktmpdir do |tmpdir|
      source_dir = Pathname.new(File.join(tmpdir, "sources"))
      cache_dir = Pathname.new(File.join(tmpdir, "cache"))

      stub_const("RemoteAudioFileDownloader::SOURCE_DIR", source_dir)
      stub_const("RemoteAudioFileDownloader::CACHE_DIR", cache_dir)

      cache = ActiveSupport::Cache::FileStore.new(cache_dir)

      first_tempfile = Tempfile.new([ "source-a", ".mp3" ])
      second_tempfile = Tempfile.new([ "source-b", ".mp3" ])
      first_tempfile.write("aaa")
      first_tempfile.flush
      second_tempfile.write("bbb")
      second_tempfile.flush

      down = class_double("Down").as_stubbed_const
      expect(down).to receive(:download).with("https://cdn.example.com/a.mp3", hash_including(open_timeout: 10, read_timeout: 120)).once.and_return(first_tempfile)
      expect(down).to receive(:download).with("https://cdn.example.com/b.mp3", hash_including(open_timeout: 10, read_timeout: 120)).once.and_return(second_tempfile)

      urls = [
        "https://cdn.example.com/a.mp3#t=0,30",
        "https://cdn.example.com/b.mp3",
        "https://cdn.example.com/a.mp3#t=30,60"
      ]

      first_result = described_class.new(urls: urls, cache: cache).call
      second_result = described_class.new(urls: urls, cache: cache).call

      expect(first_result.size).to eq(2)
      expect(first_result.map(&:url)).to eq([
        "https://cdn.example.com/a.mp3",
        "https://cdn.example.com/b.mp3"
      ])
      expect(first_result.map(&:path)).to all(satisfy { |path| File.exist?(path) })
      expect(second_result.map(&:path)).to eq(first_result.map(&:path))
    ensure
      first_tempfile.close! if defined?(first_tempfile) && first_tempfile
      second_tempfile.close! if defined?(second_tempfile) && second_tempfile
    end
  end

  it "uses namespace version in source cache key" do
    cache = ActiveSupport::Cache::MemoryStore.new
    downloader = described_class.new(urls: [ "https://cdn.example.com/a.mp3" ], cache: cache, namespace_version: "custom-v9")

    key = downloader.send(:source_cache_key, "abc123")
    expect(key).to eq([ "custom-v9", "source", "abc123" ])
  end
end
