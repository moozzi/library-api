require "rails_helper"

RSpec.describe "Api::V1::Books", type: :request do
  let!(:book) { Book.create!(serial_number: "123456", title: "Foo", author: "Baz") }
  let!(:reader) { Reader.create!(full_name: "Jan Kowalski", email: "jan@example.com", card_number: "10000001") }

  describe "GET /api/v1/books" do
    it "returns active books with their status and pagination meta" do
      borrowed = Book.create!(serial_number: "654321", title: "Bar", author: "Baz")
      borrowed.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)

      get api_v1_books_path

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["books"]).to eq([
        { "serial_number" => "123456", "title" => "Foo", "author" => "Baz", "status" => "available" },
        { "serial_number" => "654321", "title" => "Bar", "author" => "Baz", "status" => "borrowed" }
      ])
      expect(response.parsed_body["meta"]).to eq("page" => 1, "total_pages" => 1)
    end

    it "does not return deleted books" do
      Book.create!(serial_number: "654321", title: "Bar", author: "Baz", deleted_at: Time.zone.now)

      get api_v1_books_path

      expect(response.parsed_body["books"].pluck("serial_number")).to eq([ "123456" ])
    end

    it "paginates books" do
      20.times { |i| Book.create!(serial_number: format("%06d", i + 1), title: "Foo", author: "Baz") }

      get api_v1_books_path, params: { page: 2 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["books"].size).to eq(1)
      expect(response.parsed_body["meta"]).to eq("page" => 2, "total_pages" => 2)
    end
  end

  describe "GET /api/v1/books/:serial_number" do
    it "returns the book with its borrowing history" do
      book.borrowings.create!(
        reader: reader,
        borrowed_at: Time.zone.parse("2026-01-01 10:00"),
        due_date: Date.new(2026, 1, 31),
        returned_at: Time.zone.parse("2026-01-20 12:00")
      )

      get api_v1_book_path("123456")

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.slice("serial_number", "title", "author")).to eq(
        "serial_number" => "123456", "title" => "Foo", "author" => "Baz"
      )
      expect(body["borrowings"].size).to eq(1)
      expect(body["borrowings"].first["due_date"]).to eq("2026-01-31")
      expect(body["borrowings"].first["returned_at"]).to be_present
      expect(body["borrowings"].first["reader"]).to eq(
        "card_number" => "10000001", "full_name" => "Jan Kowalski", "email" => "jan@example.com"
      )
    end

    it "returns 404 for an unknown book" do
      get api_v1_book_path("999999")

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq("message" => "Resource not found")
    end

    it "returns 404 for a deleted book" do
      book.update!(deleted_at: Time.zone.now)

      get api_v1_book_path("123456")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/books" do
    it "creates a book" do
      expect {
        post api_v1_books_path, params: { book: { serial_number: "654321", title: "Bar", author: "Baz" } }, as: :json
      }.to change(Book, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq("serial_number" => "654321", "title" => "Bar", "author" => "Baz")
    end

    it "returns validation errors for invalid attributes" do
      expect {
        post api_v1_books_path, params: { book: { serial_number: "12a", title: "", author: "" } }, as: :json
      }.not_to change(Book, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to contain_exactly(
        { "field" => "serial_number", "message" => "Serial number must be exactly 6 digits" },
        { "field" => "title", "message" => "Title can't be blank" },
        { "field" => "author", "message" => "Author can't be blank" }
      )
    end

    it "returns 409 when an active book with the same serial number exists" do
      post api_v1_books_path, params: { book: { serial_number: "123456", title: "Bar", author: "Baz" } }, as: :json

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to eq("message" => "Resource already exists")
    end

    it "returns 400 when the book params are missing" do
      post api_v1_books_path, params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("message" => "param is missing or the value is empty or invalid: book")
    end
  end

  describe "DELETE /api/v1/books/:serial_number" do
    it "soft deletes an available book" do
      delete api_v1_book_path("123456")

      expect(response).to have_http_status(:no_content)
      expect(book.reload.deleted_at).to be_present
    end

    it "does not delete a borrowed book" do
      book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)

      delete api_v1_book_path("123456")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("message" => "Book 123456 is already borrowed and cannot be deleted")
      expect(book.reload.deleted_at).to be_nil
    end

    it "returns 404 for an unknown book" do
      delete api_v1_book_path("999999")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/books/:serial_number/borrow" do
    it "borrows the book for the reader and schedules reminders" do
      post borrow_api_v1_book_path("123456"), params: { card_number: "10000001" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("serial_number" => "123456", "title" => "Foo", "author" => "Baz")

      borrowing = book.borrowings.sole
      expect(borrowing.reader).to eq(reader)
      expect(borrowing.returned_at).to be_nil
      expect(borrowing.due_date).to eq(Date.current + Borrowing::LOAN_PERIOD)
      expect(borrowing.reminders.pluck(:kind, :scheduled_for)).to contain_exactly(
        [ "before_due", borrowing.due_date - Reminder::BEFORE_DUE_PERIOD ],
        [ "on_due", borrowing.due_date ]
      )
    end

    it "returns 422 when the book is already borrowed" do
      book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)

      expect {
        post borrow_api_v1_book_path("123456"), params: { card_number: "10000001" }, as: :json
      }.not_to change(Borrowing, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("message" => "Book is currently borrowed")
    end

    it "returns 400 when the card number is missing" do
      post borrow_api_v1_book_path("123456"), params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq("message" => "param is missing or the value is empty or invalid: card_number")
    end

    it "returns 404 for an unknown card number" do
      post borrow_api_v1_book_path("123456"), params: { card_number: "99999999" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(book.borrowings).to be_empty
    end

    it "returns 404 for a deleted book" do
      book.update!(deleted_at: Time.zone.now)

      post borrow_api_v1_book_path("123456"), params: { card_number: "10000001" }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(book.borrowings).to be_empty
    end

    it "returns 404 for an unknown book" do
      post borrow_api_v1_book_path("999999"), params: { card_number: "10000001" }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/books/:serial_number/return_book" do
    it "returns the book and cancels pending reminders" do
      borrowing = book.borrowings.create!(reader: reader, borrowed_at: Time.zone.now, due_date: Date.current + Borrowing::LOAN_PERIOD)
      borrowing.reminders.create!(kind: :before_due, scheduled_for: borrowing.due_date - Reminder::BEFORE_DUE_PERIOD)
      borrowing.reminders.create!(kind: :on_due, scheduled_for: borrowing.due_date)

      post return_book_api_v1_book_path("123456")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("serial_number" => "123456", "title" => "Foo", "author" => "Baz")
      expect(borrowing.reload.returned_at).to be_present
      expect(borrowing.reminders.pluck(:status)).to all(eq("cancelled"))
    end

    it "returns 422 when the book is not borrowed" do
      post return_book_api_v1_book_path("123456")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("message" => "Book is not borrowed")
    end

    it "returns 404 for an unknown book" do
      post return_book_api_v1_book_path("999999")

      expect(response).to have_http_status(:not_found)
    end
  end
end
