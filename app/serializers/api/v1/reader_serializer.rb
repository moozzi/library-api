module Api::V1
  class ReaderSerializer
    include Alba::Resource

    attributes :card_number, :full_name, :email
  end
end
