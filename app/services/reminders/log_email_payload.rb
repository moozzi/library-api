module Reminders
  class LogEmailPayload < ApplicationService
    TOPICS = {
      "before_due" => "Your book is due in #{Reminder::BEFORE_DUE_PERIOD.inspect}",
      "on_due" => "Your book is due today"
    }.freeze

    def initialize(reminder)
      @reminder = reminder
    end

    def call
      borrowing = @reminder.borrowing

      Rails.logger.info({
        event: "reminder.sent",
        kind: @reminder.kind,
        to: borrowing.reader.email,
        subject: "#{TOPICS.fetch(@reminder.kind)}: #{borrowing.book.title}",
        reader: borrowing.reader.full_name,
        book_serial_number: borrowing.book.serial_number,
        due_date: borrowing.due_date
      }.to_json)
    end
  end
end
