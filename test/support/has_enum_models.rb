# frozen_string_literal: true

require_relative "enums"

# HasEnum: no Rails involved, a reader, a writer and predicates on any class.
class Flower
  include Shy::Enum::HasEnum

  enum Color
end
