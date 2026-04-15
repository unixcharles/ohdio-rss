class ResolveAudioContentJob < OhdioApiJob
  def perform(audio_content_id)
    audio_content = AudioContent.find_by(id: audio_content_id)
    return if audio_content.nil? || audio_content.resolved?

    OhdioApiThrottle.call
    client = Ohdio::Client.new
    audio_url = client.get_media_url(audio_content.external_id)

    audio_content.update!(
      audio_url: audio_url,
      resolved: true,
      resolve_error: nil,
      resolved_at: Time.current,
      last_attempted_at: Time.current
    )
  rescue Ohdio::Error => e
    audio_content&.update_columns(resolve_error: e.message, last_attempted_at: Time.current)
    raise
  end
end
