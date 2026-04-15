# frozen_string_literal: true

module Ohdio
  class Error < StandardError; end
  class ApiError < Error; end
  class NotFoundError < Error; end
  class UnknownTypeError < Error; end
end
