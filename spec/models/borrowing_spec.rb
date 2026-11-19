require "rails_helper"

RSpec.describe Borrowing, type: :model do
  let(:book)     { Book.create!(serial_number: "123456", title: "Foo", author: "Baz") }
  let(:reader)   { Reader.create!(full_name: "Jan Kowalski", email: "jan@example.com", card_number: "10000001") }
  let(:due_date) { Date.current + Borrowing::LOAN_PERIOD }

  it "has a 30 day loan period" do
    expect(Borrowing::LOAN_PERIOD).to eq(30.days)
  end

  describe "validations" do
    it "is valid with book, reader, borrowed_at and due_date" do
      borrowing = Borrowing.new(book: book, reader: reader, borrowed_at: Time.zone.now, due_date: due_date)

      expect(borrowing).to be_valid
    end

    it "requires a book" do
      borrowing = Borrowing.new(book: nil, reader: reader, borrowed_at: Time.zone.now, due_date: due_date)

      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:book]).to include("must exist")
    end

    it "requires a reader" do
      borrowing = Borrowing.new(book: book, reader: nil, borrowed_at: Time.zone.now, due_date: due_date)

      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:reader]).to include("must exist")
    end

    it "requires borrowed_at" do
      borrowing = Borrowing.new(book: book, reader: reader, borrowed_at: nil, due_date: due_date)

      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:borrowed_at]).to include("can't be blank")
    end

    it "requires a due date" do
      borrowing = Borrowing.new(book: book, reader: reader, borrowed_at: Time.zone.now, due_date: nil)

      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:due_date]).to include("can't be blank")
    end
  end

  describe "one active borrowing per book" do
    it "does not allow a second active borrowing of the same book" do
      Borrowing.create!(book: book, reader: reader, borrowed_at: Time.zone.now, due_date: due_date)

      expect {
        Borrowing.create!(book: book, reader: reader, borrowed_at: Time.zone.now, due_date: due_date)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows borrowing the book again after it was returned" do
      Borrowing.create!(book: book, reader: reader, borrowed_at: 2.days.ago, due_date: due_date, returned_at: Time.zone.now)

      expect {
        Borrowing.create!(book: book, reader: reader, borrowed_at: Time.zone.now, due_date: due_date)
      }.not_to raise_error
    end
  end

  describe "#destroy" do
    it "destroys its reminders" do
      borrowing = Borrowing.create!(book: book, reader: reader, borrowed_at: Time.zone.now, due_date: due_date)
      borrowing.reminders.create!(kind: :on_due, scheduled_for: due_date)

      expect { borrowing.destroy }.to change(Reminder, :count).by(-1)
    end
  end
end
