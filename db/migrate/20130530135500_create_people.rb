class CreatePeople < ActiveRecord::Migration
  def change
    create_table :people do |t|
			t.references :user, index: true
			t.belongs_to :market, index: true

      t.string :name
      t.string :state
      t.float :contribution, :default => 0.0
      t.float :purchase_power, :default => 0.0
      t.float :picsy_effect, :default => 0.0

      t.timestamps
    end
  end
end
