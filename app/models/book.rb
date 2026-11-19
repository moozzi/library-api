class Book < ApplicationRecord
  has_many :borrowings, dependent: :restrict_with_error
  has_one :current_borrowing, -> { where(returned_at: nil) }, class_name: "Borrowing"

  scope :not_deleted, -> { where(deleted_at: nil) }

  normalizes :serial_number, with: ->(value) { value.strip }

  validates :serial_number, presence: true, format: { with: /\A\d{6}\z/, message: "must be exactly 6 digits" }
  validates :title, :author, presence: true

  def borrowed?
    current_borrowing.present?
  end

  def status
    borrowed? ? "borrowed" : "available"
  end

  def soft_destroy!
    with_lock do
      if borrowed?
        raise BookAlreadyBorrowed, "Book #{serial_number} is already borrowed and cannot be deleted"
      end

      update!(deleted_at: Time.zone.now)
    end
  end
end
