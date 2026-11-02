# frozen_string_literal: true

require "test_helper"

module Shy
  class HasEnumTest < Minitest::Test
    class Color < Shy::Enum::Base
      Pink = new
      Red = new
      Violet = new

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
      @subject.color = Color::Pink

      assert_equal Color::Pink, @subject.color
    end

    def test_enum_type_is_enforced
      error = assert_raises Shy::Enum::Error do
        @subject.color = String.new("Wooof")
      end
      assert_equal "Type error. Enum type must be a Shy::HasEnumTest::Color", error.message
    end

    def test_setting_enum_with_bang_method
      @subject.pink!

      assert_equal Color::Pink, @subject.color
    end

    def test_checking_enum_with_predicate_method
      @subject.pink!

      assert_predicate @subject, :pink?
    end

    class CustomNameSubject
      include Shy::Enum::HasEnum

      enum Color, as: :hue
    end

    class StringNameSubject
      include Shy::Enum::HasEnum

      enum Color, as: "tint"
    end

    def test_custom_accessor_name
      subject = CustomNameSubject.new

      assert_respond_to subject, :hue
      assert_respond_to subject, :hue=
      assert_respond_to subject, :pink?
      assert_respond_to subject, :pink!
      refute_respond_to subject, :color
      refute_respond_to subject, :color=
    end

    def test_custom_accessor_reads_and_writes
      subject = CustomNameSubject.new
      subject.hue = Color::Red

      assert_equal Color::Red, subject.hue
      subject.pink!

      assert_equal Color::Pink, subject.hue
      assert_predicate subject, :pink?
    end

    def test_custom_accessor_enforces_type
      error = assert_raises Shy::Enum::Error do
        CustomNameSubject.new.hue = "red"
      end
      assert_equal "Type error. Enum type must be a Shy::HasEnumTest::Color", error.message
    end

    def test_custom_accessor_name_as_string
      subject = StringNameSubject.new
      subject.tint = Color::Violet

      assert_equal Color::Violet, subject.tint
    end

    class ::TopLevelSeason < Shy::Enum::Base
      Spring = new

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
