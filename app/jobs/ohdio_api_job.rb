class OhdioApiJob < ApplicationJob
  include OhdioRateLimitedRetry

  queue_as :ohdio_api

  # How long a deduplication key is held at most. A key is released as soon as its job finishes;
  # this only bounds how long a lost job (e.g. a crashed worker) can block its replacement.
  DEDUP_WINDOW = 3.hours

  # Ohdio calls are serialized by running the ohdio_api queue on a single-threaded worker (see
  # config/queue.yml), so jobs no longer share one global concurrency limit. Instead each job type
  # declares what makes it unique: enqueuing a job whose key is already queued or running is
  # discarded rather than queued again. Without this, the 15-minute refresh keeps re-enqueueing the
  # same show/page/episode work faster than it drains and the queue grows without bound.
  def self.deduplicate_by(&key)
    limits_concurrency to: 1, key: key, duration: DEDUP_WINDOW, on_conflict: :discard
  end
end
