class FeedRefreshScheduler
  ENQUEUE_TTL = 5.minutes
  @memory_last_enqueued_at = {}

  def self.enqueue(show_id, force: false)
    return if show_id.blank?

    if force || should_enqueue?(show_id)
      SyncShowJob.perform_later(show_id)
    end
  end

  def self.reset_memory_cache!
    @memory_last_enqueued_at = {}
  end

  def self.should_enqueue?(show_id)
    last_enqueued_at = @memory_last_enqueued_at[show_id.to_s]
    return false if last_enqueued_at && (Time.current - last_enqueued_at) < ENQUEUE_TTL

    key = cache_key(show_id)

    write_result = Rails.cache.write(key, true, expires_in: ENQUEUE_TTL, unless_exist: true)
    if write_result
      @memory_last_enqueued_at[show_id.to_s] = Time.current
      return true
    end

    false
  rescue ArgumentError
    return false if Rails.cache.read(key)

    Rails.cache.write(key, true, expires_in: ENQUEUE_TTL)
    @memory_last_enqueued_at[show_id.to_s] = Time.current
    true
  end
  private_class_method :should_enqueue?

  def self.cache_key(show_id)
    [ "show-refresh-enqueued", show_id.to_s ]
  end
  private_class_method :cache_key
end
