# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "shy/enum"

require "minitest/autorun"

class Color < Shy::Enum::Base
  t :PINK
  t :RED
  t :VIOLET
end

class ClosedEnum < Shy::Enum::Base
  close!
end

class Subject
  extend Shy::Enum::HasEnum

  enum Color
end
