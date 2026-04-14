class AddSegmentQueryAndValidSegments < ActiveRecord::Migration[8.1]
  def change
    add_column :feeds, :segment_query, :text
    add_column :episodes, :has_valid_segments, :boolean, null: false, default: true
  end
end
