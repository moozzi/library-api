class BookAlreadyBorrowed < ApplicationError
  def initialize(message = "Book is currently borrowed")
    super
  end
end
