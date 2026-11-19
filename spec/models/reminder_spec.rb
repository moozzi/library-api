require "rails_helper"

RSpec.describe Reminder, type: :model do
  let(:reader)     { Reader.create!(full_name: "Jan Kowalski", email: "jan@example.com", card_number: "10000001") }
  let(:book)       { Book.create!(serial_number: "123456", title: "Foo", author: "Baz") }
  let(:other_book) { Book.create!(serial_number: "654321", title: "Bar", author: "Baz") }
  let(:borrowing) do
    book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)
  end
  let(:other_borrowing) do
    other_book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)
  end

  it "sends the before due reminder 3 days before the due date" do
    expect(Reminder::BEFORE_DUE_PERIOD).to eq(3.days)
  end

  describe "defaults" do
    it "is pending when created" do
      reminder = borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.current)

      expect(reminder).to be_pending
    end
  end

  describe "enums" do
    it "defines reminder kinds" do
      expect(Reminder.kinds).to eq("before_due" => "before_due", "on_due" => "on_due")
    end

    it "defines reminder statuses" do
      expect(Reminder.statuses).to eq(
        "pending" => "pending",
        "sent" => "sent",
        "cancelled" => "cancelled",
        "failed" => "failed"
      )
    end

    it "rejects an unknown kind" do
      expect { Reminder.new(kind: :overdue) }.to raise_error(ArgumentError)
    end
  end

  describe "validations" do
    it "requires a borrowing" do
      reminder = Reminder.new(kind: :on_due, scheduled_for: Date.current)

      expect(reminder).not_to be_valid
      expect(reminder.errors[:borrowing]).to include("must exist")
    end

    it "allows only one reminder of each kind per borrowing" do
      borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.current)
      duplicate = borrowing.reminders.build(kind: :on_due, scheduled_for: Date.current)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:kind]).to include("has already been taken")
    end

    it "allows different kinds for the same borrowing" do
      borrowing.reminders.create!(kind: :before_due, scheduled_for: Date.current)

      expect(borrowing.reminders.build(kind: :on_due, scheduled_for: Date.current)).to be_valid
    end

    it "allows the same kind for different borrowings" do
      borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.current)

      expect(other_borrowing.reminders.build(kind: :on_due, scheduled_for: Date.current)).to be_valid
    end
  end

  describe ".due" do
    let!(:due_today) { borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.current) }

    it "returns pending reminders scheduled for today" do
      expect(Reminder.due).to contain_exactly(due_today)
    end

    it "excludes reminders scheduled for a past day" do
      past = borrowing.reminders.create!(kind: :before_due, scheduled_for: Date.yesterday)

      expect(Reminder.due).not_to include(past)
    end

    it "excludes reminders scheduled for a future day" do
      future = other_borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.tomorrow)

      expect(Reminder.due).not_to include(future)
    end

    %i[sent cancelled failed].each do |status|
      it "excludes #{status} reminders" do
        reminder = other_borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.current, status: status)

        expect(Reminder.due).not_to include(reminder)
      end
    end
  end
end
