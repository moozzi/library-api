require "rails_helper"

RSpec.describe Book, type: :model do
  let(:reader) { Reader.create!(full_name: "Jan Kowalski", email: "jan@kowalski.com", card_number: "111111") }
  let(:book)   { Book.create!(serial_number: "123456", title: "Foo", author: "Baz") }

  describe "validations" do
    it "is valid with serial number, title and author" do
      book = Book.new(serial_number: "123456", title: "Foo", author: "Foo")

      expect(book).to be_valid
    end

    it "requires a serial number" do
      book = Book.new(serial_number: nil, title: "Foo", author: "Baz")

      expect(book).not_to be_valid
      expect(book.errors[:serial_number]).to include("can't be blank")
    end

    it "requires a title" do
      book = Book.new(serial_number: "123456", title: "", author: "Baz")

      expect(book).not_to be_valid
      expect(book.errors[:title]).to include("can't be blank")
    end

    it "requires an author" do
      book = Book.new(serial_number: "123456", title: "Foo", author: "")

      expect(book).not_to be_valid
      expect(book.errors[:author]).to include("can't be blank")
    end

    %w[12345 1234567 12a456 abcdef].each do |serial_number|
      it "rejects serial number #{serial_number.inspect}" do
        book = Book.new(serial_number: serial_number, title: "Foo", author: "Baz")

        expect(book).not_to be_valid
        expect(book.errors[:serial_number]).to include("must be exactly 6 digits")
      end
    end

    it "accepts a serial number with leading zeros" do
      book = Book.new(serial_number: "000123", title: "Foo", author: "Baz")

      expect(book).to be_valid
    end
  end

  describe "normalization" do
    it "strips whitespace from the serial number" do
      book = Book.new(serial_number: " 123456 ", title: "Foo", author: "Baz")

      expect(book.serial_number).to eq("123456")
    end
  end

  describe "serial number uniqueness" do
    it "does not allow two active books with the same serial number" do
      Book.create!(serial_number: "123456", title: "Foo", author: "Baz")

      expect {
        Book.create!(serial_number: "123456", title: "Bar", author: "Baz")
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows reusing the serial number of a deleted book" do
      Book.create!(serial_number: "123456", title: "Foo", author: "Baz", deleted_at: Time.zone.now)

      expect {
        Book.create!(serial_number: "123456", title: "Bar", author: "Baz")
      }.not_to raise_error
    end
  end

  describe ".not_deleted" do
    it "returns only books that are not deleted" do
      active = Book.create!(serial_number: "111111", title: "Foo", author: "Baz")
      Book.create!(serial_number: "222222", title: "Bar", author: "Baz", deleted_at: Time.zone.now)

      expect(Book.not_deleted).to contain_exactly(active)
    end
  end

  describe "#borrowed?" do
    it "returns false when the book has never been borrowed" do
      expect(book).not_to be_borrowed
    end

    it "returns true when the book has an active borrowing" do
      book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)

      expect(book.reload).to be_borrowed
    end

    it "returns false after the book is returned" do
      book.borrowings.create!(
        reader: reader,
        borrowed_at: 2.days.ago,
        due_date: Date.current + Borrowing::LOAN_PERIOD,
        returned_at: Time.zone.now
      )

      expect(book.reload).not_to be_borrowed
    end
  end

  describe "#status" do
    it "returns available when the book has never been borrowed" do
      expect(book.status).to eq("available")
    end

    it "returns borrowed when the book has an active borrowing" do
      book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)

      expect(book.reload.status).to eq("borrowed")
    end

    it "returns available after the book is returned" do
      book.borrowings.create!(
        reader: reader,
        borrowed_at: 2.days.ago,
        due_date: Date.current + Borrowing::LOAN_PERIOD,
        returned_at: Time.zone.now
      )

      expect(book.reload.status).to eq("available")
    end
  end

  describe "#current_borrowing" do
    it "returns the active borrowing only" do
      book.borrowings.create!(
        reader: reader,
        borrowed_at: 10.days.ago,
        due_date: Date.current + Borrowing::LOAN_PERIOD,
        returned_at: 5.days.ago
      )
      active = book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)

      expect(book.reload.current_borrowing).to eq(active)
    end
  end

  describe "#soft_destroy!" do
    it "sets deleted_at for an available book" do
      book.soft_destroy!

      expect(book.reload.deleted_at).to be_present
    end

    it "raises BookAlreadyBorrowed and keeps a borrowed book" do
      book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)

      expect { book.soft_destroy! }.to raise_error(BookAlreadyBorrowed, "Book 123456 is already borrowed and cannot be deleted")
      expect(book.reload.deleted_at).to be_nil
    end
  end

  describe "#destroy" do
    it "is restricted when the book has borrowings" do
      book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)

      expect(book.destroy).to be(false)
      expect(book.errors[:base]).to be_present
      expect(Book.exists?(book.id)).to be(true)
    end
  end
end
