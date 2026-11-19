class Borrowing < ApplicationRecord
  LOAN_PERIOD = 30.days

  belongs_to :book
  belongs_to :reader

  has_many :reminders, dependent: :destroy

  validates :borrowed_at, :due_date, presence: true
end
