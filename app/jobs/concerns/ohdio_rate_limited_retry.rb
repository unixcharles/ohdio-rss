module OhdioRateLimitedRetry
  extend ActiveSupport::Concern

  BASE_RETRY_SECONDS = 30
  MAX_RETRY_SECONDS = 600
  RETRY_JITTER_MAX_SECONDS = 3
  RETRY_ATTEMPTS = 12

  included do
    retry_on Ohdio::Error,
             wait: ->(*args) { ohdio_retry_wait_seconds(args.first) },
             attempts: RETRY_ATTEMPTS

    around_perform :register_global_cooldown_on_error
  end

  class_methods do
    def ohdio_retry_wait_seconds(executions)
      base_wait = [ BASE_RETRY_SECONDS * (2**(executions - 1)), MAX_RETRY_SECONDS ].min
      base_wait + rand(0.0..RETRY_JITTER_MAX_SECONDS)
    end
  end

  private

  def register_global_cooldown_on_error
    yield
  rescue Ohdio::Error
    OhdioApiThrottle.register_error!
    raise
  end
end
