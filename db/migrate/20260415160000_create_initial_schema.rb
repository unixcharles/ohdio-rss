class CreateInitialSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :audio_contents do |t|
      t.string :external_id, null: false
      t.string :audio_url
      t.boolean :resolved, null: false, default: false
      t.datetime :resolved_at
      t.text :resolve_error
      t.datetime :last_attempted_at

      t.timestamps
    end
    add_index :audio_contents, :external_id, unique: true

    create_table :shows do |t|
      t.integer :external_id, null: false
      t.string :title
      t.text :description
      t.string :image_url
      t.string :ohdio_type
      t.integer :page_size
      t.integer :total_episodes
      t.string :url
      t.string :sync_status, null: false, default: "pending"
      t.text :sync_error
      t.datetime :last_synced_at
      t.integer :highest_max_episodes

      t.timestamps
    end
    add_index :shows, :external_id, unique: true

    create_table :feeds do |t|
      t.string :name, null: false
      t.integer :show_external_id, null: false
      t.string :uid, null: false
      t.boolean :exclude_replays, null: false, default: true
      t.integer :max_episodes, null: false, default: 100
      t.text :episode_query
      t.text :segment_query

      t.timestamps
    end
    add_index :feeds, :show_external_id
    add_index :feeds, :uid, unique: true

    create_table :episodes do |t|
      t.references :show, null: false, foreign_key: true
      t.string :ohdio_episode_id, null: false
      t.string :title
      t.text :description
      t.datetime :published_at
      t.integer :duration
      t.boolean :is_replay
      t.string :url
      t.string :audio_url
      t.string :audio_content_external_id
      t.boolean :has_valid_segments, null: false, default: true

      t.timestamps
    end
    add_index :episodes, [ :show_id, :ohdio_episode_id ], unique: true
    add_index :episodes, :audio_content_external_id

    create_table :segments do |t|
      t.references :episode, null: false, foreign_key: true
      t.string :title
      t.integer :duration
      t.integer :seek_time
      t.integer :position
      t.string :audio_content_external_id

      t.timestamps
    end
    add_index :segments, [ :episode_id, :position ]
    add_index :segments, [ :episode_id, :audio_content_external_id ],
              name: "index_segments_on_episode_id_and_audio_content_external_id"
  end
end
