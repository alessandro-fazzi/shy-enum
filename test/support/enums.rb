# frozen_string_literal: true

# Example enums shared by the tests and by bin/console.

# Stored as a string.
class Status < Shy::Enum::Base
  Draft = new
  InProgress = new
  Published = new

  freeze
end

# Stored as an integer.
class Priority < Shy::Enum::Base
  Low = new(0)
  High = new(1)

  freeze
end

class Color < Shy::Enum::Base
  Pink = new
  Red = new
  Violet = new

  freeze
end
