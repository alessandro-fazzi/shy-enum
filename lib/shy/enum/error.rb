# frozen_string_literal: true

module Shy
  module Enum
    # Custom error class for Shy::Enum
    #
    # ## Example
    #
    # ```ruby
    # raise Error, "Can't add new values to a closed Enum"
    # ```
    class Error < StandardError; end
  end
end
