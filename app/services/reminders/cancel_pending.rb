module Reminders
  class CancelPending < ApplicationService
    def initialize(borrowing)
      @borrowing = borrowing
    end

    def call
      @borrowing.reminders.pending.update_all(status: "cancelled", updated_at: Time.zone.now)
    end
  end
end
