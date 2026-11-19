module Api::V1
  class BorrowingSerializer
    include Alba::Resource

    attributes :borrowed_at, :due_date, :returned_at
    one :reader, resource: ReaderSerializer
  end
end
