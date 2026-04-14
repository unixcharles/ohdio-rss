class OhdioApiJob < ApplicationJob
  include OhdioRateLimitedRetry

  queue_as :ohdio_api

  limits_concurrency to: 1, key: ->(*) { "ohdio-api-global" }, duration: 1.minute
end
