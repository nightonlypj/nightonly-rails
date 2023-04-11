class CreateSlackDomains < ActiveRecord::Migration[6.1]
  def change
    create_table :slack_domains do |t|
      t.string :name

      t.timestamps
    end
  end
end
