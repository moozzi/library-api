class Reminder < ApplicationRecord
  BEFORE_DUE_PERIOD = 3.days

  belongs_to :borrowing

  enum :kind, {
    before_due: "before_due",
    on_due: "on_due"
  }
  enum :status, {
    pending: "pending",
    sent: "sent",
    cancelled: "cancelled",
    failed: "failed"
  }

  scope :due, -> { pending.where(scheduled_for: Date.current) }

  validates :kind, uniqueness: { scope: :borrowing_id }
end
