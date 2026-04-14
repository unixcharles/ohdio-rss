require "digest"
require "fileutils"
require "securerandom"

class RemoteAudioSegmentJoiner
  OUTPUT_TTL = 1.year
  OUTPUT_DIR = Rails.root.join("tmp", "audio_segment_joined")
  CACHE_DIR = Rails.root.join("tmp", "cache", "audio_segment_joined")
  CLIP_DIR = Rails.root.join("tmp", "audio_segment_clips")

  def initialize(segments:, cache: ActiveSupport::Cache::FileStore.new(CACHE_DIR), namespace_version: "remote-audio-segment-joiner-v1", downloader_class: RemoteAudioFileDownloader)
    @segments = Array(segments)
    @cache = cache
    @namespace_version = namespace_version
    @downloader_class = downloader_class
  end

  def call
    raise ArgumentError, "no segments provided" if @segments.empty?

    FileUtils.mkdir_p(OUTPUT_DIR)
    FileUtils.mkdir_p(CACHE_DIR)
    FileUtils.mkdir_p(CLIP_DIR)

    cache_key = joined_cache_key
    cached_path = @cache.read(cache_key)
    return cached_path if cached_path.present? && File.exist?(cached_path)

    downloaded_files = @downloader_class.new(urls: @segments.map { |segment| segment.fetch(:url) }).call
    downloaded_by_url = downloaded_files.index_by(&:url)

    clip_paths = @segments.each_with_index.map do |segment, index|
      source = downloaded_by_url.fetch(segment.fetch(:url), nil)
      raise ArgumentError, "missing downloaded source" if source.nil?

      build_clip(source.path, segment.fetch(:start_time).to_f, segment.fetch(:duration).to_f, index)
    end

    output_path = output_path_for(cache_key)
    concat_list_path = write_concat_list(clip_paths)
    run_ffmpeg_concat(concat_list_path, output_path)

    @cache.write(cache_key, output_path, expires_in: OUTPUT_TTL)
    output_path
  ensure
    FileUtils.rm_f(concat_list_path) if defined?(concat_list_path) && concat_list_path
  end

  private

  def joined_cache_key
    serialized = @segments.map do |segment|
      [ segment.fetch(:url), segment.fetch(:start_time).to_f.round(3), segment.fetch(:duration).to_f.round(3) ].join("|")
    end

    [ @namespace_version, Digest::SHA256.hexdigest(serialized.join("\n")) ]
  end

  def output_path_for(cache_key)
    digest = Digest::SHA256.hexdigest(cache_key.join(":"))
    OUTPUT_DIR.join("#{digest}.mp3").to_s
  end

  def build_clip(source_path, start_time, duration, index)
    raise ArgumentError, "invalid segment duration" unless duration.positive?

    clip_path = CLIP_DIR.join("clip-#{SecureRandom.hex(8)}-#{index}.mp3").to_s

    success = system(
      "ffmpeg", "-y",
      "-ss", start_time.to_s,
      "-t", duration.to_s,
      "-i", source_path,
      "-vn",
      "-acodec", "libmp3lame",
      "-b:a", "128k",
      clip_path
    )

    raise "ffmpeg segment clip failed" unless success && File.exist?(clip_path)

    clip_path
  end

  def write_concat_list(paths)
    list_path = OUTPUT_DIR.join("concat-#{SecureRandom.hex(10)}.txt").to_s
    lines = paths.map do |path|
      escaped = path.gsub("'", %q('\\''))
      "file '#{escaped}'"
    end
    File.write(list_path, lines.join("\n"))
    list_path
  end

  def run_ffmpeg_concat(concat_list_path, output_path)
    success = system(
      "ffmpeg", "-y",
      "-f", "concat",
      "-safe", "0",
      "-i", concat_list_path,
      "-vn",
      "-acodec", "libmp3lame",
      "-b:a", "128k",
      output_path
    )

    raise "ffmpeg join failed" unless success && File.exist?(output_path)
  end
end
