class AddShareUrlToSegments < ActiveRecord::Migration[8.1]
  def change
    add_column :segments, :share_url, :string
  end
end
