require "rails_helper"

RSpec.describe DeliverReminderJob, type: :job do
  include ActiveJob::TestHelper

  let(:reader) { Reader.create!(full_name: "Jan Kowalski", email: "jan@example.com", card_number: "10000001") }
  let(:book)   { Book.create!(serial_number: "123456", title: "Foo", author: "Baz") }
  let(:borrowing) do
    book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)
  end
  let(:reminder) { borrowing.reminders.create!(kind: :on_due, scheduled_for: Date.current) }

  describe "#perform" do
    it "marks the reminder as sent" do
      described_class.perform_now(reminder)

      expect(reminder.reload).to be_sent
      expect(reminder.sent_at).to be_present
    end

    it "cancels the reminder when the book was already returned" do
      borrowing.update!(returned_at: Time.zone.now)
      allow(Reminders::LogEmailPayload).to receive(:call)

      described_class.perform_now(reminder)

      expect(Reminders::LogEmailPayload).not_to have_received(:call)
      expect(reminder.reload).to be_cancelled
      expect(reminder.sent_at).to be_nil
    end

    %i[sent cancelled failed].each do |status|
      it "does nothing for a #{status} reminder" do
        reminder.update!(status: status)
        allow(Reminders::LogEmailPayload).to receive(:call)

        described_class.perform_now(reminder)

        expect(Reminders::LogEmailPayload).not_to have_received(:call)
        expect(reminder.reload.status).to eq(status.to_s)
      end
    end
  end

  describe "retries" do
    it "keeps the reminder pending and schedules a retry when sending fails" do
      allow(Reminders::LogEmailPayload).to receive(:call).and_raise(StandardError, "smtp down")

      described_class.perform_now(reminder)

      expect(reminder.reload).to be_pending
      expect(described_class).to have_been_enqueued.with(reminder)
    end

    it "marks the reminder as failed after the last attempt" do
      allow(Reminders::LogEmailPayload).to receive(:call).and_raise(StandardError, "smtp down")

      perform_enqueued_jobs { described_class.perform_later(reminder) }

      expect(Reminders::LogEmailPayload).to have_received(:call).exactly(3).times
      expect(reminder.reload).to be_failed
      expect(reminder.sent_at).to be_nil
    end
  end

  describe "deleted reminder" do
    it "discards the job without raising" do
      described_class.perform_later(reminder)
      reminder.destroy!
      allow(Reminders::LogEmailPayload).to receive(:call)

      expect { perform_enqueued_jobs }.not_to raise_error
      expect(performed_jobs.size).to eq(1)
      expect(Reminders::LogEmailPayload).not_to have_received(:call)
    end
  end
end
