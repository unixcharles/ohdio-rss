require "digest"
require "fileutils"
require "securerandom"

class RemoteAudioFileJoiner
  OUTPUT_TTL = 1.year
  OUTPUT_DIR = Rails.root.join("tmp", "audio_joined")
  CACHE_DIR = Rails.root.join("tmp", "cache", "audio_joined")

  def initialize(urls:, cache: ActiveSupport::Cache::FileStore.new(CACHE_DIR), namespace_version: "remote-audio-file-joiner-v1", downloader_class: RemoteAudioFileDownloader)
    @urls = Array(urls).map(&:to_s)
    @cache = cache
    @namespace_version = namespace_version
    @downloader_class = downloader_class
  end

  def call
    raise ArgumentError, "no urls provided" if @urls.empty?

    FileUtils.mkdir_p(OUTPUT_DIR)
    FileUtils.mkdir_p(CACHE_DIR)

    cache_key = joined_cache_key
    cached_path = @cache.read(cache_key)
    return cached_path if cached_path.present? && File.exist?(cached_path)

    downloaded_files = @downloader_class.new(urls: @urls).call
    raise ArgumentError, "no downloadable audio files" if downloaded_files.empty?

    output_path = output_path_for(cache_key)
    concat_list_path = write_concat_list(downloaded_files.map(&:path))

    run_ffmpeg_concat(concat_list_path, output_path)

    @cache.write(cache_key, output_path, expires_in: OUTPUT_TTL)
    output_path
  ensure
    FileUtils.rm_f(concat_list_path) if defined?(concat_list_path) && concat_list_path
  end

  private

  def joined_cache_key
    [ @namespace_version, Digest::SHA256.hexdigest(@urls.join("\n")) ]
  end

  def output_path_for(cache_key)
    digest = Digest::SHA256.hexdigest(cache_key.join(":"))
    OUTPUT_DIR.join("#{digest}.mp3").to_s
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
