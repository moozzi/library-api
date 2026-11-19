class Reader < ApplicationRecord
  has_many :borrowings, dependent: :restrict_with_error

  normalizes :card_number, with: ->(value) { value.strip }
  normalizes :email, with: ->(value) { value.strip.downcase }

  validates :card_number, :email, :full_name, presence: true
  validates :email, uniqueness: true
end
