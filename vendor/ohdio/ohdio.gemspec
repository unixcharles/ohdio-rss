# frozen_string_literal: true

require_relative 'lib/ohdio/version'

Gem::Specification.new do |spec|
  spec.name = 'ohdio'
  spec.version = Ohdio::VERSION
  spec.authors = [ 'Charles Barbier' ]
  spec.email = [ 'unixcharles@gmail.com' ]

  spec.summary = 'A Ruby client for the Radio-Canada Ohdio audio streaming API'
  spec.description = 'Fetches programme data, episodes, segments, and audio URLs from Radio-Canada\'s Ohdio service'
  spec.homepage = 'https://github.com/unixcharles/ohdio'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://github.com/unixcharles/ohdio/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # Use a pure Ruby file listing so this works without git.
  gemspec = File.basename(__FILE__)
  spec.files = Dir.glob("**/*", File::FNM_DOTMATCH, base: __dir__).reject do |f|
    next true if [ ".", "..", gemspec ].include?(f)
    next true if File.directory?(File.join(__dir__, f))

    f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .git/ .claude/])
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ 'lib' ]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
