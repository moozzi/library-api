require "rails_helper"

RSpec.describe Borrowings::BorrowBook do
  include ActiveSupport::Testing::TimeHelpers

  let(:reader) { Reader.create!(full_name: "Jan Kowalski", email: "jan@example.com", card_number: "10000001") }
  let(:book)   { Book.create!(serial_number: "123456", title: "Foo", author: "Baz") }

  it "creates an active borrowing for the reader" do
    freeze_time do
      borrowing = described_class.call(book, reader)

      expect(borrowing).to be_persisted
      expect(borrowing.book).to eq(book)
      expect(borrowing.reader).to eq(reader)
      expect(borrowing.borrowed_at).to eq(Time.zone.now)
      expect(borrowing.due_date).to eq(Date.current + Borrowing::LOAN_PERIOD)
      expect(borrowing.returned_at).to be_nil
    end
  end

  it "marks the book as borrowed" do
    described_class.call(book, reader)

    expect(book.reload).to be_borrowed
  end

  it "schedules reminders for the borrowing" do
    borrowing = described_class.call(book, reader)

    expect(borrowing.reminders.pluck(:kind, :scheduled_for, :status)).to contain_exactly(
      [ "before_due", borrowing.due_date - Reminder::BEFORE_DUE_PERIOD, "pending" ],
      [ "on_due", borrowing.due_date, "pending" ]
    )
  end

  it "raises BookAlreadyBorrowed when the book has an active borrowing" do
    book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)

    expect { described_class.call(book, reader) }.to raise_error(BookAlreadyBorrowed, "Book is currently borrowed")
    expect(Borrowing.count).to eq(1)
    expect(Reminder.count).to eq(0)
  end

  it "borrows a book that was returned before" do
    book.borrowings.create!(
      reader: reader,
      borrowed_at: 10.days.ago,
      due_date: Date.current + Borrowing::LOAN_PERIOD,
      returned_at: 5.days.ago
    )

    expect { described_class.call(book, reader) }.to change(Borrowing, :count).by(1)
  end

  it "raises RecordNotFound when the book was deleted after it was loaded" do
    loaded_book = Book.find(book.id)
    book.update!(deleted_at: Time.zone.now)

    expect { described_class.call(loaded_book, reader) }.to raise_error(ActiveRecord::RecordNotFound)
    expect(Borrowing.count).to eq(0)
  end

  it "does not create the borrowing when scheduling reminders fails" do
    allow(Reminders::Schedule).to receive(:call).and_raise(StandardError, "boom")

    expect { described_class.call(book, reader) }.to raise_error(StandardError, "boom")
    expect(Borrowing.count).to eq(0)
  end
end
