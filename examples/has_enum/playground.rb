#!/usr/bin/env ruby
# frozen_string_literal: true

# HasEnum playground: plain Ruby objects, no Rails.
#
# It stops at the end with `binding.irb`: the local variables below are available there.

require "bundler/setup"
require "shy/enum"

# Everything lives here, so the example classes don't leak into the top level.
module Playground
  # Members are stored by value, here the downcased name.
  class Color < Shy::Enum::Base
    Pink = new
    Red = new
    Violet = new

    freeze
  end

  # A reader, a writer and a predicate and a setter for each member.
  class Flower
    include Shy::Enum::HasEnum

    enum Color
  end

  # `as:` renames the reader and the writer; predicates and setters keep the member names.
  class Bouquet
    include Shy::Enum::HasEnum

    enum Color, as: :petals
  end
end

include Playground # rubocop:disable Style/MixinUsage

flower = Flower.new.tap(&:pink!)
bouquet = Bouquet.new

puts <<~MSG
  Everything is in the Playground module, included at the top level so the constants
  below work unprefixed.
  Classes: Flower (enum Color), Bouquet (enum Color, as: :petals). Enum: Color.
  Variables: `flower`, `bouquet`.
  Try: flower.color
       flower.red!
       flower.red?
       flower.color = Color::Violet
       flower.color = "red" (raises Shy::Enum::Error: only members are accepted)
       bouquet.petals
       bouquet.petals = Color::Red
       bouquet.red?
MSG

binding.irb
