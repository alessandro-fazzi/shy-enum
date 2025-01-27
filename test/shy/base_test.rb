# frozen_string_literal: true

require "test_helper"

module Shy
  class ColorEnumTest < Minitest::Test
    class Subject < Shy::Enum::Base
      PINK = new
      RED = new
      VIOLET = new

      freeze
    end

    def setup
      @subject = Subject
    end

    def test_that_it_has_a_version_number
      refute_nil ::Shy::Enum::VERSION
    end

    def test_enum_comparisons # rubocop:disable Minitest/MultipleAssertions
      assert_operator @subject::PINK, :<, @subject::RED
      assert_operator @subject::PINK, :<, @subject::VIOLET
      assert_operator @subject::RED, :>, @subject::PINK
      assert_operator @subject::RED, :<, @subject::VIOLET
      assert_operator @subject::VIOLET, :>, @subject::PINK
      assert_operator @subject::VIOLET, :>, @subject::RED
    end

    def test_enum_registry
      assert_equal [@subject::PINK, @subject::RED, @subject::VIOLET], @subject.all
      assert_kind_of Array, @subject.registry
    end

    def test_registry_and_all_are_aliases
      assert_equal @subject.all, @subject.registry
    end

    def test_enum_values
      assert_equal %w[pink red violet], @subject.values
    end

    def test_exception_when_member_added_to_frozen_enum
      error = assert_raises Shy::Enum::Error do
        @subject.send(:new, :FOO)
      end
      assert_equal "Can't add new values to a closed Enum", error.message
    end

    def test_enum_cannot_be_instantiated
      error = assert_raises NoMethodError do
        Shy::Enum::Base.new
      end
      assert_equal "private method 'new' called for class Shy::Enum::Base", error.message
    end

    def test_you_cannot_modify_an_enum_type_once_declared
      assert_raises FrozenError do
        @subject::PINK.instance_variable_set(:@value, "Hacked")
      end
    end

    def test_enum_casting_with_brackets
      assert_equal @subject::PINK, @subject[:PINK]

      assert_raises Shy::Enum::Error do
        @subject[:NON_EXISTENT]
      end
    end

    def test_enum_casting_with_string
      assert_equal @subject::PINK, @subject["PINK"]

      error = assert_raises Shy::Enum::Error do
        @subject["NON_EXISTENT"]
      end
      assert_equal "Unknown member", error.message
    end

    class OpenEnum < Shy::Enum::Base
    end

    def test_exception_when_duplicated_member_by_const_added
      OpenEnum.const_set(:FOO, OpenEnum.send(:new))
      warning_message = /warning: already initialized constant Shy::ColorEnumTest::OpenEnum::FOO/
      error = nil

      assert_output(nil, warning_message) do
        error = assert_raises Shy::Enum::Error do
          OpenEnum.const_set(:FOO, OpenEnum.send(:new))
        end
      end
      assert_equal "Duplicated member", error.message
    end

    def test_exception_when_duplicated_member_by_value_added
      OpenEnum.const_set(:BAR, OpenEnum.send(:new, 0))

      error = assert_raises Shy::Enum::Error do
        OpenEnum.const_set(:BAZ, OpenEnum.send(:new, 0))
      end
      assert_equal "Duplicated member", error.message
    end

    def test_enum_name_property
      assert_equal "PINK", @subject::PINK.name
      assert_equal "RED", @subject::RED.name
      assert_equal "VIOLET", @subject::VIOLET.name
    end

    def test_enum_in_case_statement
      result = case @subject::RED
               when @subject::PINK then "pink"
               when @subject::RED then "red"
               when @subject::VIOLET then "violet"
               end

      assert_equal "red", result
    end

    def test_enum_in_pattern_matching
      result = case @subject::VIOLET
               in Subject::PINK then "pink"
               in Subject::RED then "red"
               in Subject::VIOLET then "violet"
               end

      assert_equal "violet", result
    end

    class SubjectSubclass < Subject
      YELLOW = new
      ORANGE = new

      freeze
    end

    def test_enum_can_be_subclassed
      assert_equal %w[pink red violet yellow orange], SubjectSubclass.values
    end
  end
end
