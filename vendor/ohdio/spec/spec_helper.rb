# frozen_string_literal: true

require 'ohdio'
require 'json'
require 'vcr'
require 'webmock/rspec'

FIXTURES_PATH = File.join(__dir__, 'fixtures')

def fixture_json(name)
  JSON.parse(File.read(File.join(FIXTURES_PATH, "#{name}.json")))
end

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = {
    record: ENV.fetch('VCR_RECORD', :none).to_sym,
    match_requests_on: %i[method host path query]
  }
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
