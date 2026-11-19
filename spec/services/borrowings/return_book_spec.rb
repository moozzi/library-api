require "rails_helper"

RSpec.describe Borrowings::ReturnBook do
  include ActiveSupport::Testing::TimeHelpers

  let(:reader) { Reader.create!(full_name: "Jan Kowalski", email: "jan@example.com", card_number: "10000001") }
  let(:book)   { Book.create!(serial_number: "123456", title: "Foo", author: "Baz") }

  it "sets returned_at on the active borrowing and returns it" do
    borrowing = book.borrowings.create!(reader: reader, borrowed_at: 3.days.ago, due_date: Date.current + Borrowing::LOAN_PERIOD)

    freeze_time do
      result = described_class.call(book)

      expect(result).to eq(borrowing)
      expect(borrowing.reload.returned_at).to eq(Time.zone.now)
    end
  end

  it "marks the book as available" do
    book.borrowings.create!(reader: reader, borrowed_at: 3.days.ago, due_date: Date.current + Borrowing::LOAN_PERIOD)

    described_class.call(book)

    expect(book.reload).not_to be_borrowed
  end

  it "cancels pending reminders and keeps the sent ones" do
    borrowing = book.borrowings.create!(reader: reader, borrowed_at: 3.days.ago, due_date: Date.current + Borrowing::LOAN_PERIOD)
    pending = borrowing.reminders.create!(kind: :on_due, scheduled_for: borrowing.due_date)
    sent = borrowing.reminders.create!(kind: :before_due, scheduled_for: Date.current, status: :sent)

    described_class.call(book)

    expect(pending.reload).to be_cancelled
    expect(sent.reload).to be_sent
  end

  it "does not change previously returned borrowings" do
    returned_at = 10.days.ago.change(usec: 0)
    old_borrowing = book.borrowings.create!(
      reader: reader,
      borrowed_at: 20.days.ago,
      due_date: Date.current + Borrowing::LOAN_PERIOD,
      returned_at: returned_at
    )
    book.borrowings.create!(reader: reader, borrowed_at: 3.days.ago, due_date: Date.current + Borrowing::LOAN_PERIOD)

    described_class.call(book)

    expect(old_borrowing.reload.returned_at).to eq(returned_at)
  end

  it "raises BookNotBorrowed when the book has no active borrowing" do
    expect { described_class.call(book) }.to raise_error(BookNotBorrowed, "Book is not borrowed")
  end

  it "raises BookNotBorrowed when the book was already returned" do
    book.borrowings.create!(
      reader: reader,
      borrowed_at: 10.days.ago,
      due_date: Date.current + Borrowing::LOAN_PERIOD,
      returned_at: 5.days.ago
    )

    expect { described_class.call(book) }.to raise_error(BookNotBorrowed)
  end

  it "does not return the book when cancelling reminders fails" do
    borrowing = book.borrowings.create!(reader: reader, borrowed_at: 3.days.ago, due_date: Date.current + Borrowing::LOAN_PERIOD)
    allow(Reminders::CancelPending).to receive(:call).and_raise(StandardError, "boom")

    expect { described_class.call(book) }.to raise_error(StandardError, "boom")
    expect(borrowing.reload.returned_at).to be_nil
  end
end
