class RenameMediaToAudioContents < ActiveRecord::Migration[8.1]
  def change
    rename_table :media, :audio_contents

    rename_column :audio_contents, :media_id, :external_id
    rename_column :episodes, :media_id, :audio_content_external_id
    rename_column :segments, :media_id, :audio_content_external_id

    rename_index :audio_contents, "index_media_on_media_id", "index_audio_contents_on_external_id"
    rename_index :episodes, "index_episodes_on_media_id", "index_episodes_on_audio_content_external_id"
    rename_index :segments, "index_segments_on_episode_id_and_media_id", "index_segments_on_episode_id_and_audio_content_external_id"
  end
end
