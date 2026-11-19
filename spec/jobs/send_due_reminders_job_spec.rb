require "rails_helper"

RSpec.describe SendDueRemindersJob, type: :job do
  let(:reader)     { Reader.create!(full_name: "Jan Kowalski", email: "jan@example.com", card_number: "10000001") }
  let(:book)       { Book.create!(serial_number: "123456", title: "Foo", author: "Baz") }
  let(:other_book) { Book.create!(serial_number: "654321", title: "Bar", author: "Baz") }
  let(:borrowing) do
    book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)
  end
  let(:other_borrowing) do
    other_book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)
  end

  it "enqueues delivery for every pending reminder scheduled for today" do
    first = borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.current)
    second = other_borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.current)

    expect { described_class.perform_now }
      .to have_enqueued_job(DeliverReminderJob).with(first)
      .and have_enqueued_job(DeliverReminderJob).with(second)
  end

  it "does not enqueue reminders scheduled for another day" do
    borrowing.reminders.create!(kind: :before_due, scheduled_for: Date.yesterday)
    other_borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.tomorrow)

    expect { described_class.perform_now }.not_to have_enqueued_job(DeliverReminderJob)
  end

  it "does not enqueue reminders that are not pending" do
    borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.current, status: :sent)
    other_borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.current, status: :cancelled)

    expect { described_class.perform_now }.not_to have_enqueued_job(DeliverReminderJob)
  end

  it "enqueues only due reminders when others exist" do
    due = borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.current)
    other_borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.tomorrow)

    expect { described_class.perform_now }.to have_enqueued_job(DeliverReminderJob).exactly(:once).with(due)
  end
end
