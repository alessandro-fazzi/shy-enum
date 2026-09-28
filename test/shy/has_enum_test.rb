# frozen_string_literal: true

require "test_helper"

module Shy
  class HasEnumTest < Minitest::Test
    class Color < Shy::Enum::Base
      PINK = new
      RED = new
      VIOLET = new

      freeze
    end

    class Subject
      include Shy::Enum::HasEnum

      enum Color
    end

    def setup
      @subject = Subject.new
    end

    def test_generated_methods
      assert_respond_to @subject, :pink?
      assert_respond_to @subject, :pink!
      assert_respond_to @subject, :red?
      assert_respond_to @subject, :red!
      assert_respond_to @subject, :violet?
      assert_respond_to @subject, :violet!
      assert_respond_to @subject, :color
      assert_respond_to @subject, :color=
    end

    def test_initial_enum_is_nil
      assert_nil @subject.color
    end

    def test_setting_enum
      @subject.color = Color::PINK

      assert_equal Color::PINK, @subject.color
    end

    def test_enum_type_is_enforced
      error = assert_raises Shy::Enum::Error do
        @subject.color = String.new("Wooof")
      end
      assert_equal "Type error. Enum type must be a Shy::HasEnumTest::Color", error.message
    end

    def test_setting_enum_with_bang_method
      @subject.pink!

      assert_equal Color::PINK, @subject.color
    end

    def test_checking_enum_with_predicate_method
      @subject.pink!

      assert_predicate @subject, :pink?
    end

    class ::TopLevelSeason < Shy::Enum::Base
      SPRING = new

      freeze
    end

    class TopLevelSubject
      include Shy::Enum::HasEnum

      enum ::TopLevelSeason
    end

    def test_generated_method_names_for_a_top_level_enum_class
      subject = TopLevelSubject.new

      assert_respond_to subject, :toplevelseason
      assert_respond_to subject, :toplevelseason=
      assert_respond_to subject, :spring?
    end
  end
end
