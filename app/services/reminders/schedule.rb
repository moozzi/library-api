module Reminders
  class Schedule < ApplicationService
    def initialize(borrowing)
      @borrowing = borrowing
    end

    def call
      Reminder.transaction do
        @borrowing.reminders.create!(kind: :before_due, scheduled_for: @borrowing.due_date - Reminder::BEFORE_DUE_PERIOD)
        @borrowing.reminders.create!(kind: :on_due, scheduled_for: @borrowing.due_date)
      end
    end
  end
end
