class CreateFeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :feeds do |t|
      t.string :name, null: false
      t.string :show_id, null: false

      t.timestamps
    end

    add_index :feeds, :show_id, unique: true
  end
end
