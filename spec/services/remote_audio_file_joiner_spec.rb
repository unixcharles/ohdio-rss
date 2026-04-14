require "rails_helper"
require "tmpdir"

RSpec.describe RemoteAudioFileJoiner do
  it "joins files once then reuses cached joined output" do
    Dir.mktmpdir do |tmpdir|
      output_dir = Pathname.new(File.join(tmpdir, "output"))
      cache_dir = Pathname.new(File.join(tmpdir, "cache"))

      stub_const("RemoteAudioFileJoiner::OUTPUT_DIR", output_dir)
      stub_const("RemoteAudioFileJoiner::CACHE_DIR", cache_dir)

      source_one = File.join(tmpdir, "one.mp3")
      source_two = File.join(tmpdir, "two.mp3")
      File.write(source_one, "one")
      File.write(source_two, "two")

      downloaded_files = [
        RemoteAudioFileDownloader::DownloadedFile.new(key: "k1", url: "u1", path: source_one),
        RemoteAudioFileDownloader::DownloadedFile.new(key: "k2", url: "u2", path: source_two)
      ]

      downloader_instance = instance_double("RemoteAudioFileDownloader", call: downloaded_files)
      downloader_class = class_double("RemoteAudioFileDownloader")
      allow(downloader_class).to receive(:new).with(urls: [ "https://cdn.example.com/a.mp3", "https://cdn.example.com/b.mp3" ]).and_return(downloader_instance)

      cache = ActiveSupport::Cache::FileStore.new(cache_dir)
      joiner = described_class.new(urls: [ "https://cdn.example.com/a.mp3", "https://cdn.example.com/b.mp3" ], cache: cache, downloader_class: downloader_class)

      expect(joiner).to receive(:run_ffmpeg_concat).once do |concat_list_path, output_path|
        lines = File.read(concat_list_path).split("\n")
        expect(lines[0]).to include(source_one)
        expect(lines[1]).to include(source_two)
        File.write(output_path, "joined")
      end

      first_path = joiner.call
      second_path = joiner.call

      expect(File.exist?(first_path)).to be(true)
      expect(second_path).to eq(first_path)
      expect(downloader_class).to have_received(:new).once
    end
  end

  it "uses url order in joined cache key fingerprint" do
    first = described_class.new(urls: [ "a", "b" ])
    second = described_class.new(urls: [ "b", "a" ])

    expect(first.send(:joined_cache_key)).not_to eq(second.send(:joined_cache_key))
  end

  it "includes namespace version in joined cache key" do
    joiner = described_class.new(urls: [ "a" ], namespace_version: "custom-v3")

    key = joiner.send(:joined_cache_key)
    expect(key.first).to eq("custom-v3")
  end
end
