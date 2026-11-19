module Api::V1
  class BooksController < BaseController
    before_action :set_book, only: [ :show, :destroy, :borrow, :return_book ]

    def index
      pagy, books = pagy(:offset, Book.not_deleted.includes(:current_borrowing).order(:id))

      render json: {
        books: BookSerializer.new(books, with_traits: :with_status).to_h, meta: pagination_meta(pagy)
      }, status: :ok
    end

    def show
      render json: BookSerializer.new(@book, with_traits: :with_borrowings).serialize, status: :ok
    end

    def create
      book = Book.new(permitted_params)
      book.save!

      render json: BookSerializer.new(book).serialize, status: :created
    end

    def destroy
      @book.soft_destroy!
      head :no_content
    end

    def borrow
      reader = Reader.find_by!(card_number: params.require(:card_number))
      Borrowings::BorrowBook.call(@book, reader)

      render json: BookSerializer.new(@book.reload).serialize, status: :ok
    end

    def return_book
      Borrowings::ReturnBook.call(@book)

      render json: BookSerializer.new(@book.reload).serialize, status: :ok
    end

    private

    def set_book
      @book = Book.not_deleted.find_by!(serial_number: params[:serial_number])
    end

    def permitted_params
      params.require(:book).permit(:title, :author, :serial_number)
    end

    def pagination_meta(pagy)
      { page: pagy.page, total_pages: pagy.pages }
    end
  end
end
