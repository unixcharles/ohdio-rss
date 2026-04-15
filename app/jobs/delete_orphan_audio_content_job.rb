class DeleteOrphanAudioContentJob < ApplicationJob
  queue_as :default

  def perform(audio_content_external_ids)
    ids = Array(audio_content_external_ids).compact_blank.uniq
    return if ids.empty?

    AudioContent.where(external_id: ids).left_outer_joins(:segments).where(segments: { id: nil }).delete_all
  end
end
