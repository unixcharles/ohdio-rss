require "open3"

# Identifies the running build. In the Docker image the values come from build args set by the
# Docker Publish workflow (the image has no .git); in a local checkout they're read from git.
module AppVersion
  UNKNOWN = "unknown".freeze

  def self.to_h
    @to_h ||= {
      sha: from_env("GIT_SHA") || from_git("rev-parse", "HEAD") || UNKNOWN,
      committed_at: from_env("GIT_COMMITTED_AT") || from_git("log", "-1", "--format=%cI") || UNKNOWN,
      built_at: from_env("BUILT_AT") || UNKNOWN
    }.freeze
  end

  def self.from_env(name)
    value = ENV[name].to_s.strip
    value unless value.empty? || value == UNKNOWN
  end
  private_class_method :from_env

  def self.from_git(*args)
    output, status = Open3.capture2("git", "-C", Rails.root.to_s, *args, err: File::NULL)
    output.strip.presence if status.success?
  rescue SystemCallError
    nil
  end
  private_class_method :from_git
end
