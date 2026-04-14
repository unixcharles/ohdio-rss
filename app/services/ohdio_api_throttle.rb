class OhdioApiThrottle
  LAST_REQUEST_AT_KEY = "ohdio:last_request_at"
  COOLDOWN_UNTIL_KEY = "ohdio:cooldown_until"
  CONSECUTIVE_ERROR_COUNT_KEY = "ohdio:consecutive_error_count"

  BASE_INTERVAL = 1.second
  BASE_COOLDOWN = 5.seconds
  MAX_COOLDOWN = 60.seconds
  JITTER_RATIO = 0.10

  def self.call(min_interval: BASE_INTERVAL)
    new(min_interval: min_interval).call
  end

  def self.register_error!
    new.register_error!
  end

  def self.reset_error_backoff!
    new.reset_error_backoff!
  end

  def initialize(min_interval: BASE_INTERVAL, cache: Rails.cache)
    @min_interval = min_interval
    @cache = cache
  end

  def call
    now = Time.current
    last_request_at = @cache.read(LAST_REQUEST_AT_KEY)
    cooldown_until = @cache.read(COOLDOWN_UNTIL_KEY)

    next_slot_at = next_request_slot(last_request_at, now)
    wait_until = [ now, next_slot_at, cooldown_until ].compact.max
    wait_for = wait_until - now

    sleep(wait_for) if wait_for.positive?

    @cache.write(LAST_REQUEST_AT_KEY, Time.current, expires_in: 2.hours)
  end

  def register_error!
    consecutive_errors = @cache.read(CONSECUTIVE_ERROR_COUNT_KEY).to_i + 1
    @cache.write(CONSECUTIVE_ERROR_COUNT_KEY, consecutive_errors, expires_in: 2.hours)

    base_cooldown = [ BASE_COOLDOWN * (2**(consecutive_errors - 1)), MAX_COOLDOWN ].min
    jittered_cooldown = apply_jitter(base_cooldown)

    proposed_until = Time.current + jittered_cooldown
    existing_until = @cache.read(COOLDOWN_UNTIL_KEY)
    cooldown_until = existing_until.present? && existing_until > proposed_until ? existing_until : proposed_until

    @cache.write(COOLDOWN_UNTIL_KEY, cooldown_until, expires_in: 2.hours)
  end

  def reset_error_backoff!
    @cache.delete(COOLDOWN_UNTIL_KEY)
    @cache.delete(CONSECUTIVE_ERROR_COUNT_KEY)
  end

  private

  def next_request_slot(last_request_at, now)
    return now if last_request_at.blank?

    last_request_at + @min_interval
  end

  def apply_jitter(duration)
    jitter = duration * rand(-JITTER_RATIO..JITTER_RATIO)
    [ duration + jitter, 1.second ].max
  end
end
