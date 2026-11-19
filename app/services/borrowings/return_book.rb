module Borrowings
  class ReturnBook < ApplicationService
    def initialize(book)
      @book = book
    end

    def call
      Book.transaction do
        @book.lock!

        borrowing = @book.borrowings.find_by(returned_at: nil)
        raise BookNotBorrowed unless borrowing

        borrowing.update!(returned_at: Time.zone.now)
        Reminders::CancelPending.call(borrowing)
        borrowing
      end
    end
  end
end
