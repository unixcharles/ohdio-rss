class CreateFeedFilters < ActiveRecord::Migration[8.1]
  def change
    create_table :feed_filters do |t|
      t.references :feed, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :keyword, null: false
      t.boolean :include, null: false, default: true

      t.timestamps
    end
    add_index :feed_filters, [ :feed_id, :kind ]
  end
end
