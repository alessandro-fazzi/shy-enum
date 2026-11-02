# frozen_string_literal: true

require_relative "enum/version"
require_relative "enum/error"
require_relative "enum/has_enum"
require_relative "enum/base"

# Namespace of the shy-enum gem.
module Shy
  # Small, dependency-free enums for plain Ruby.
  #
  # * Base - subclass it to define an enum and its members
  # * HasEnum - include it to plug an enum into any class
  # * ActiveModelType - opt-in ActiveModel type, `require "shy/enum/active_model"`
  # * ActiveRecordEnum - opt-in ActiveRecord macro, `require "shy/enum/active_record"`
  # * Error - raised on invalid definitions, lookups and assignments
  #
  # ```ruby
  # require "shy/enum"
  #
  # class Color < Shy::Enum::Base
  #   Red = new
  #   Green = new
  #
  #   freeze
  # end
  # ```
  module Enum
  end
end
