class ResolveMediaJob < OhdioApiJob
  def perform(medium_id)
    medium = Medium.find_by(id: medium_id)
    return if medium.nil? || medium.resolved?

    OhdioApiThrottle.call
    client = Ohdio::Client.new
    audio_url = client.get_media_url(medium.media_id)

    medium.update!(
      audio_url: audio_url,
      resolved: true,
      resolve_error: nil,
      resolved_at: Time.current,
      last_attempted_at: Time.current
    )
  rescue Ohdio::Error => e
    medium&.update_columns(resolve_error: e.message, last_attempted_at: Time.current)
    raise
  end
end
