require "rails_helper"

RSpec.describe Reminders::CancelPending do
  let(:reader)     { Reader.create!(full_name: "Jan Kowalski", email: "jan@example.com", card_number: "10000001") }
  let(:book)       { Book.create!(serial_number: "123456", title: "Foo", author: "Baz") }
  let(:other_book) { Book.create!(serial_number: "654321", title: "Bar", author: "Baz") }
  let(:borrowing) do
    book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)
  end
  let(:other_borrowing) do
    other_book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)
  end

  it "cancels pending reminders of the borrowing" do
    before_due = borrowing.reminders.create!(kind: :before_due, scheduled_for: Date.current)
    on_due = borrowing.reminders.create!(kind: :on_due, scheduled_for: borrowing.due_date)

    described_class.call(borrowing)

    expect(before_due.reload).to be_cancelled
    expect(on_due.reload).to be_cancelled
  end

  it "keeps reminders that are not pending" do
    sent = borrowing.reminders.create!(kind: :before_due, scheduled_for: Date.current, status: :sent)
    failed = borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.current, status: :failed)

    described_class.call(borrowing)

    expect(sent.reload).to be_sent
    expect(failed.reload).to be_failed
  end

  it "does not touch reminders of other borrowings" do
    other = other_borrowing.reminders.create!(kind: :on_due, scheduled_for: other_borrowing.due_date)

    described_class.call(borrowing)

    expect(other.reload).to be_pending
  end
end
