require "rails_helper"

RSpec.describe Reader, type: :model do
  let(:reader) { Reader.create!(full_name: "Jan Kowalski", email: "jan@example.com", card_number: "10000001") }

  describe "validations" do
    it "is valid with full name, email and card number" do
      reader = Reader.new(full_name: "Jan Kowalski", email: "jan@example.com", card_number: "10000001")

      expect(reader).to be_valid
    end

    it "requires a full name" do
      reader = Reader.new(full_name: "", email: "jan@example.com", card_number: "10000001")

      expect(reader).not_to be_valid
      expect(reader.errors[:full_name]).to include("can't be blank")
    end

    it "requires an email" do
      reader = Reader.new(full_name: "Jan Kowalski", email: nil, card_number: "10000001")

      expect(reader).not_to be_valid
      expect(reader.errors[:email]).to include("can't be blank")
    end

    it "requires a card number" do
      reader = Reader.new(full_name: "Jan Kowalski", email: "jan@example.com", card_number: nil)

      expect(reader).not_to be_valid
      expect(reader.errors[:card_number]).to include("can't be blank")
    end

    it "requires a unique email regardless of case" do
      Reader.create!(full_name: "Jan Kowalski", email: "jan@example.com", card_number: "10000001")
      duplicate = Reader.new(full_name: "Jan Nowak", email: "JAN@Example.com", card_number: "10000002")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:email]).to include("has already been taken")
    end
  end

  describe "normalization" do
    it "strips and downcases the email" do
      reader = Reader.new(full_name: "Jan Kowalski", email: "  Jan@Example.COM ", card_number: "10000001")

      expect(reader.email).to eq("jan@example.com")
    end

    it "strips the card number" do
      reader = Reader.new(full_name: "Jan Kowalski", email: "jan@example.com", card_number: " 10000001 ")

      expect(reader.card_number).to eq("10000001")
    end

    it "finds a reader by a card number with surrounding whitespace" do
      reader

      expect(Reader.find_by(card_number: " 10000001 ")).to eq(reader)
    end
  end

  describe "card number uniqueness" do
    it "does not allow two readers with the same card number" do
      reader

      expect {
        Reader.create!(full_name: "Jan Nowak", email: "nowak@example.com", card_number: "10000001")
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "#destroy" do
    it "is restricted when the reader has borrowings" do
      book = Book.create!(serial_number: "123456", title: "Foo", author: "Baz")
      reader.borrowings.create!(book: book, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)

      expect(reader.destroy).to be(false)
      expect(reader.errors[:base]).to be_present
      expect(Reader.exists?(reader.id)).to be(true)
    end

    it "destroys a reader without borrowings" do
      reader

      expect { reader.destroy }.to change(Reader, :count).by(-1)
    end
  end
end
