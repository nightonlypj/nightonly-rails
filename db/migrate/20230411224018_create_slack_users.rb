class CreateSlackUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :slack_users do |t|
      t.references :slack_domain, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :memberid
      t.string :string

      t.timestamps
    end
  end
end
