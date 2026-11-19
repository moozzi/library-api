module Borrowings
  class BorrowBook < ApplicationService
    def initialize(book, reader)
      @book = book
      @reader = reader
    end

    def call
      Book.transaction do
        @book.lock!

        raise ActiveRecord::RecordNotFound if @book.deleted_at.present?
        raise BookAlreadyBorrowed if @book.borrowings.where(returned_at: nil).exists?

        borrowing = @book.borrowings.create!(
          reader: @reader,
          borrowed_at: Time.zone.now,
          due_date: Date.current + Borrowing::LOAN_PERIOD
        )
        Reminders::Schedule.call(borrowing)
        borrowing
      end
    end
  end
end
