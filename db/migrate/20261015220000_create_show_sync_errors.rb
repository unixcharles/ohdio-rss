class CreateShowSyncErrors < ActiveRecord::Migration[8.1]
  def change
    create_table :show_sync_errors do |t|
      t.references :show, null: false, foreign_key: true
      t.string :kind, null: false
      t.text :message, null: false
      t.integer :occurrences, default: 1, null: false
      t.datetime :last_occurred_at, null: false
      t.timestamps
    end

    add_index :show_sync_errors, [ :show_id, :last_occurred_at ]
  end
end
