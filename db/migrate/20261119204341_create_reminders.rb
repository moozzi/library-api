class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders do |t|
      t.references :borrowing, null: false, foreign_key: true
      t.string :kind, null: false
      t.date :scheduled_for, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :sent_at

      t.timestamps
    end

    add_index :reminders, [ :borrowing_id, :kind ],
              unique: true,
              name: "index_reminders_on_borrowing_id_and_kind"

    add_index :reminders, :scheduled_for,
              where: "status = 'pending'",
              name: "index_reminders_on_scheduled_for_pending"
  end
end
