return if Rails.env.production?

books = []
10.times do
  books << Book.create!(
    serial_number: Faker::Number.unique.number(digits: 6).to_s,
    title: Faker::Book.title,
    author: Faker::Book.author
  )
end

Reader.create!(
  full_name: Faker::Name.name,
  email: Faker::Internet.unique.email,
  card_number: Faker::Number.unique.number(digits: 8).to_s
)

past_reader = Reader.create!(
  full_name: Faker::Name.name,
  email: Faker::Internet.unique.email,
  card_number: Faker::Number.unique.number(digits: 8).to_s
)
past_reader.borrowings.create!(
  book: books[0],
  borrowed_at: 90.days.ago,
  due_date: 60.days.ago,
  returned_at: 70.days.ago
)
past_reader.borrowings.create!(
  book: books[1],
  borrowed_at: 45.days.ago,
  due_date: 15.days.ago,
  returned_at: 20.days.ago
)

first_active_reader = Reader.create!(
  full_name: Faker::Name.name,
  email: Faker::Internet.unique.email,
  card_number: Faker::Number.unique.number(digits: 8).to_s
)
first_borrowing = first_active_reader.borrowings.create!(
  book: books[2],
  borrowed_at: 27.days.ago,
  due_date: 3.days.from_now.to_date
)
Reminders::Schedule.call(first_borrowing)

second_active_reader = Reader.create!(
  full_name: Faker::Name.name,
  email: Faker::Internet.unique.email,
  card_number: Faker::Number.unique.number(digits: 8).to_s
)
second_borrowing = second_active_reader.borrowings.create!(
  book: books[3],
  borrowed_at: 30.days.ago,
  due_date: Date.current
)
Reminders::Schedule.call(second_borrowing)
