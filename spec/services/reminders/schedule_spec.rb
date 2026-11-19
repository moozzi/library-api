require "rails_helper"

RSpec.describe Reminders::Schedule do
  let(:reader) { Reader.create!(full_name: "Jan Kowalski", email: "jan@example.com", card_number: "10000001") }
  let(:book)   { Book.create!(serial_number: "123456", title: "Foo", author: "Baz") }
  let(:borrowing) do
    book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.new(2026, 12, 31))
  end

  it "creates a before due reminder and an on due reminder" do
    described_class.call(borrowing)

    expect(borrowing.reminders.pluck(:kind, :scheduled_for)).to contain_exactly(
      [ "before_due", Date.new(2026, 12, 28) ],
      [ "on_due", Date.new(2026, 12, 31) ]
    )
  end

  it "creates pending reminders" do
    described_class.call(borrowing)

    expect(borrowing.reminders.pluck(:status)).to all(eq("pending"))
  end

  it "creates no reminders when one of them cannot be saved" do
    borrowing.reminders.create!(kind: :on_due, scheduled_for: borrowing.due_date)

    expect { described_class.call(borrowing) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(borrowing.reminders.pluck(:kind)).to eq([ "on_due" ])
  end
end
