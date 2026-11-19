class ApplicationError < StandardError
  attr_reader :status

  DEFAULT_MESSAGE = "Something went wrong"

  def initialize(message = nil, status: :unprocessable_content)
    super(message || DEFAULT_MESSAGE)
    @status = status
  end
end
