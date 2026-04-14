require "digest"
require "fileutils"
require "uri"

class RemoteAudioFileDownloader
  SOURCE_TTL = 1.year
  SOURCE_DIR = Rails.root.join("tmp", "audio_sources")
  CACHE_DIR = Rails.root.join("tmp", "cache", "audio_sources")

  DownloadedFile = Struct.new(:key, :url, :path, keyword_init: true)

  def initialize(urls:, cache: ActiveSupport::Cache::FileStore.new(CACHE_DIR), namespace_version: "remote-audio-file-downloader-v1")
    @urls = Array(urls).map(&:to_s)
    @cache = cache
    @namespace_version = namespace_version
  end

  def call
    FileUtils.mkdir_p(SOURCE_DIR)
    FileUtils.mkdir_p(CACHE_DIR)

    unique_urls.map do |url|
      key = url_digest(url)
      cache_key = source_cache_key(key)
      path = @cache.read(cache_key)

      if path.present? && File.exist?(path)
        DownloadedFile.new(key: key, url: url, path: path)
      else
        destination = source_path_for(key, url)
        download_to(destination, url) unless File.exist?(destination)
        @cache.write(cache_key, destination, expires_in: SOURCE_TTL)
        DownloadedFile.new(key: key, url: url, path: destination)
      end
    end
  end

  private

  def unique_urls
    seen = {}

    @urls.filter_map do |url|
      normalized = normalize_url(url)
      next if normalized.blank?

      key = url_digest(normalized)
      next if seen[key]

      seen[key] = true
      normalized
    end
  end

  def normalize_url(url)
    stripped = url.to_s.strip
    return nil if stripped.empty?

    uri = URI.parse(stripped)
    uri.fragment = nil
    uri.to_s
  rescue URI::InvalidURIError
    stripped
  end

  def source_path_for(key, url)
    ext = file_extension_for(url)
    SOURCE_DIR.join("#{key}#{ext}").to_s
  end

  def file_extension_for(url)
    path = URI.parse(url).path
    ext = File.extname(path)
    ext.empty? ? ".mp3" : ext
  rescue URI::InvalidURIError
    ".mp3"
  end

  def url_digest(url)
    Digest::SHA256.hexdigest(url)
  end

  def source_cache_key(url_digest)
    [ @namespace_version, "source", url_digest ]
  end

  def download_to(destination, url)
    tempfile = Down.download(url, max_size: nil, open_timeout: 10, read_timeout: 120)
    FileUtils.cp(tempfile.path, destination)
    tempfile.close! if tempfile.respond_to?(:close!)
  end
end
