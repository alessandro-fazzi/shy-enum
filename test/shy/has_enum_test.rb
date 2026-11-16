# frozen_string_literal: true

require_relative "test_helper"
require "support/has_enum_models"

module Shy
  class HasEnumTest < Minitest::Test
    def setup
      @subject = Flower.new
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
      assert_equal "Type error. Enum type must be a Color", error.message
    end

    def test_setting_enum_with_bang_method
      @subject.pink!

      assert_equal Color::Pink, @subject.color
    end

    def test_checking_enum_with_predicate_method
      @subject.pink!

      assert_predicate @subject, :pink?
    end

    class CustomNameFlower
      include Shy::Enum::HasEnum

      enum Color, as: :hue
    end

    class StringNameFlower
      include Shy::Enum::HasEnum

      enum Color, as: "tint"
    end

    def test_custom_accessor_name
      subject = CustomNameFlower.new

      assert_respond_to subject, :hue
      assert_respond_to subject, :hue=
      assert_respond_to subject, :pink?
      assert_respond_to subject, :pink!
      refute_respond_to subject, :color
      refute_respond_to subject, :color=
    end

    def test_custom_accessor_reads_and_writes
      subject = CustomNameFlower.new
      subject.hue = Color::Red

      assert_equal Color::Red, subject.hue
      subject.pink!

      assert_equal Color::Pink, subject.hue
      assert_predicate subject, :pink?
    end

    def test_custom_accessor_enforces_type
      error = assert_raises Shy::Enum::Error do
        CustomNameFlower.new.hue = "red"
      end
      assert_equal "Type error. Enum type must be a Color", error.message
    end

    def test_custom_accessor_name_as_string
      subject = StringNameFlower.new
      subject.tint = Color::Violet

      assert_equal Color::Violet, subject.tint
    end

    class ::TopLevelSeason < Shy::Enum::Base
      Spring = new

      freeze
    end

    class TopLevelFlower
      include Shy::Enum::HasEnum

      enum ::TopLevelSeason
    end

    def test_generated_method_names_for_a_top_level_enum_class
      subject = TopLevelFlower.new

      assert_respond_to subject, :toplevelseason
      assert_respond_to subject, :toplevelseason=
      assert_respond_to subject, :spring?
    end

    class PrefixTest < Minitest::Test
      class PrefixTrue
        include Shy::Enum::HasEnum

        enum Color, prefix: true
      end

      class PrefixSymbol
        include Shy::Enum::HasEnum

        enum Color, prefix: :foo
      end

      class PrefixTrueWithCustomName
        include Shy::Enum::HasEnum

        enum Color, as: :hue, prefix: true
      end

      class PrefixAndSuffix
        include Shy::Enum::HasEnum

        enum Color, prefix: :a, suffix: :b
      end

      class ::Paint < Shy::Enum::Base
        Red = new
        Blue = new

        freeze
      end

      class PrefixTrueOnTwoEnumsSharingValues
        include Shy::Enum::HasEnum

        enum Color, prefix: true
        enum ::Paint, prefix: true
      end

      class PrefixTrueOnIntegerValues
        include Shy::Enum::HasEnum

        enum Priority, prefix: true
      end

      def test_prefix_true_uses_the_accessor_name
        subject = PrefixTrue.new
        subject.color_red!

        assert_predicate subject, :color_red?
        assert_equal Color::Red, subject.color
      end

      def test_prefix_removes_bare_methods
        subject = PrefixTrue.new

        refute_respond_to subject, :red?
        refute_respond_to subject, :red!
        assert_respond_to subject, :color
        assert_respond_to subject, :color=
      end

      def test_prefix_as_symbol
        subject = PrefixSymbol.new
        subject.foo_pink!

        assert_predicate subject, :foo_pink?
        refute_respond_to subject, :pink?
      end

      def test_prefix_true_with_custom_accessor_name
        subject = PrefixTrueWithCustomName.new
        subject.hue_violet!

        assert_equal Color::Violet, subject.hue
        assert_predicate subject, :hue_violet?
        refute_respond_to subject, :color_violet?
      end

      def test_prefix_and_suffix_together
        subject = PrefixAndSuffix.new
        subject.a_red_b!

        assert_predicate subject, :a_red_b?
        refute_respond_to subject, :red?
      end

      def test_enums_with_shared_values_do_not_collide
        subject = PrefixTrueOnTwoEnumsSharingValues.new
        subject.color_red!
        subject.paint_blue!

        assert_equal Color::Red, subject.color
        assert_equal Paint::Blue, subject.paint
        assert_predicate subject, :color_red?
        refute_predicate subject, :paint_red?
      end

      def test_prefix_makes_integer_values_callable
        subject = PrefixTrueOnIntegerValues.new
        subject.priority_2!

        assert_predicate subject, :priority_2?
        assert_equal Priority::High, subject.priority
      end
    end

    class SuffixTest < Minitest::Test
      class SuffixTrue
        include Shy::Enum::HasEnum

        enum Color, suffix: true
      end

      class SuffixString
        include Shy::Enum::HasEnum

        enum Color, suffix: "foo"
      end

      def test_suffix_true_uses_the_accessor_name
        subject = SuffixTrue.new
        subject.red_color!

        assert_predicate subject, :red_color?
        assert_equal Color::Red, subject.color
        refute_respond_to subject, :red?
      end

      def test_suffix_as_string
        subject = SuffixString.new
        subject.pink_foo!

        assert_predicate subject, :pink_foo?
        refute_respond_to subject, :pink!
      end
    end
  end
end
