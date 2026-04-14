class CreateReplicatedOhdioData < ActiveRecord::Migration[8.1]
  def change
    create_table :shows do |t|
      t.integer :ohdio_id, null: false
      t.string :title
      t.text :description
      t.string :image_url
      t.string :ohdio_type
      t.string :url
      t.integer :page_size
      t.integer :total_episodes
      t.string :sync_status, null: false, default: "pending"
      t.text :sync_error
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :shows, :ohdio_id, unique: true

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
      t.integer :page_number
      t.integer :position

      t.timestamps
    end
    add_index :episodes, [ :show_id, :ohdio_episode_id ], unique: true
    add_index :episodes, [ :show_id, :position ]

    create_table :media do |t|
      t.string :media_id, null: false
      t.string :audio_url
      t.boolean :resolved, null: false, default: false
      t.text :resolve_error
      t.datetime :resolved_at
      t.datetime :last_attempted_at

      t.timestamps
    end
    add_index :media, :media_id, unique: true

    create_table :segments do |t|
      t.references :episode, null: false, foreign_key: true
      t.string :title
      t.integer :duration
      t.integer :seek_time
      t.string :media_id
      t.integer :position

      t.timestamps
    end
    add_index :segments, [ :episode_id, :position ]
    add_index :segments, [ :episode_id, :media_id ]
  end
end
