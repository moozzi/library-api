class BookNotBorrowed < ApplicationError
  def initialize(message = "Book is not borrowed")
    super
  end
end
