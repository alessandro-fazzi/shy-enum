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

  # Another enum sharing `Red` with Color.
  class Paint < Shy::Enum::Base
    Blue = new
    Red = new

    freeze
  end

  # Without a prefix, `red?` and `red!` would be defined twice and the last enum would win.
  # `prefix: true` names them after the accessor (`color_red?`, `paint_red?`); a String or
  # a Symbol is used as is, and `suffix:` works the same way.
  class Wall
    include Shy::Enum::HasEnum

    enum Color, prefix: true
    enum Paint, prefix: true
  end
end

include Playground # rubocop:disable Style/MixinUsage

flower = Flower.new.tap(&:pink!)
bouquet = Bouquet.new
wall = Wall.new

puts <<~MSG
  Everything is in the Playground module, included at the top level so the constants
  below work unprefixed.
  Classes: Flower (enum Color), Bouquet (enum Color, as: :petals),
  Wall (enum Color and enum Paint, both prefix: true). Enums: Color, Paint.
  Variables: `flower`, `bouquet`, `wall`.
  Try: flower.color
       flower.red!
       flower.red?
       flower.color = Color::Violet
       flower.color = "red" (raises Shy::Enum::Error: only members are accepted)
       bouquet.petals
       bouquet.petals = Color::Red
       bouquet.red?
       wall.color_red!
       wall.paint_red!
       wall.color_red?
       wall.color
       wall.paint
MSG

binding.irb
