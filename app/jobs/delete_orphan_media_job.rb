class DeleteOrphanMediaJob < ApplicationJob
  queue_as :default

  def perform(media_ids)
    ids = Array(media_ids).compact_blank.uniq
    return if ids.empty?

    Medium.where(media_id: ids).left_outer_joins(:segments).where(segments: { id: nil }).delete_all
  end
end
