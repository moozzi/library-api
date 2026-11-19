module Api::V1
  class BookSerializer
    include Alba::Resource

    attributes :serial_number, :title, :author

    trait :with_status do
      attributes :status
    end

    trait :with_borrowings do
      many :borrowings, resource: BorrowingSerializer
    end
  end
end
