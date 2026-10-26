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

    # Ease some tests avoiding to freeze
    class OpenEnum < Shy::Enum::Base
    end

    def setup
      @subject = Subject
    end

    def test_that_it_has_a_version_number
      refute_nil ::Shy::Enum::VERSION
    end

    def test_enum_comparisons
      assert_operator @subject::PINK, :<, @subject::RED
      assert_operator @subject::PINK, :<, @subject::VIOLET
      assert_operator @subject::RED, :>, @subject::PINK
      assert_operator @subject::RED, :<, @subject::VIOLET
      assert_operator @subject::VIOLET, :>, @subject::PINK
      assert_operator @subject::VIOLET, :>, @subject::RED
    end

    def test_spaceship_operator_returns_ordinal_comparison
      assert_equal(-1, @subject::PINK <=> @subject::RED)
      assert_equal(0, @subject::PINK <=> @subject::PINK) # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
      assert_equal(1, @subject::VIOLET <=> @subject::RED)
    end

    def test_enum_is_sortable
      assert_equal [@subject::PINK, @subject::RED, @subject::VIOLET],
                   [@subject::VIOLET, @subject::PINK, @subject::RED].sort
    end

    def test_spaceship_operator_returns_nil_when_other_is_not_comparable
      assert_nil(@subject::PINK <=> "not an enum")
    end

    def test_enum_registry
      assert_equal [@subject::PINK, @subject::RED, @subject::VIOLET], @subject.all
      assert_kind_of Array, @subject.registry
    end

    def test_registry_and_all_are_aliases
      assert_equal @subject.all, @subject.registry
    end

    def test_each_yields_members_in_declaration_order
      yielded = []
      @subject.each { yielded << it } # rubocop:disable Style/MapIntoArray

      assert_equal [@subject::PINK, @subject::RED, @subject::VIOLET], yielded
    end

    def test_each_returns_the_enum_class
      assert_same(@subject, @subject.each { nil })
    end

    def test_each_without_block_returns_an_enumerator
      enumerator = @subject.each

      assert_kind_of Enumerator, enumerator
      assert_equal @subject.all, enumerator.to_a
    end

    def test_size_returns_the_number_of_members
      assert_equal 3, @subject.size
      assert_equal 5, SubjectSubclass.size
    end

    def test_enumerator_knows_its_size_without_iterating
      assert_equal 3, @subject.each.size
    end

    def test_enum_is_enumerable
      assert_kind_of Enumerable, @subject
      assert_equal %w[PINK RED VIOLET], @subject.map(&:name)
      assert_equal(@subject::RED, @subject.find { it.value == "red" })
      assert_equal @subject::VIOLET, @subject.max
    end

    def test_enumerable_does_not_leak_members_between_subclasses
      assert_equal %w[pink red violet yellow orange], SubjectSubclass.map(&:value)
      assert_equal %w[pink red violet], Subject.map(&:value)
    end

    def test_include_keeps_module_semantics
      assert Subject.include?(Comparable) # rubocop:disable Minitest/AssertIncludes
      error = assert_raises(TypeError) { Subject.include?(Subject::PINK) }
      assert_match(/member\?/, error.message)
    end

    # RuboCop suggests assert_includes, which relies on `include?`: on enums it
    # checks for included modules, so `member?` must be asserted directly.
    # rubocop:disable Minitest/AssertIncludes, Minitest/RefuteIncludes
    def test_member_with_a_member
      assert Subject.member?(Subject::PINK)
    end

    def test_member_with_a_member_of_a_subclass
      refute Subject.member?(SubjectSubclass::YELLOW)
    end

    def test_member_with_a_value
      assert Subject.member?("pink")
      refute Subject.member?("brown")
    end

    def test_member_with_a_member_of_another_enum_sharing_a_value
      refute Subject.member?(OtherColor::PINK)
    end
    # rubocop:enable Minitest/AssertIncludes, Minitest/RefuteIncludes

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

    def test_unrelated_constant_added_to_enum_is_ignored
      OpenEnum.const_set(:UNRELATED, "just a string")

      refute_includes OpenEnum.registry.map(&:name), "UNRELATED"
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

    def test_subclassing_does_not_affect_the_original_enum
      assert_equal %w[pink red violet], Subject.values
      refute_includes Subject.values, "yellow"
      refute_includes Subject.values, "orange"
    end

    def test_how_member_is_inspected
      assert_equal "Shy::ColorEnumTest::Subject::PINK", @subject::PINK.inspect
    end

    def test_member_prints_its_value_when_converted_to_string
      assert_equal "pink", @subject::PINK.to_s
    end

    def test_equality_with_other_type_returns_false
      # Order of the compared objects is strict: swapping the two would exercise
      # `String#==` instead of our implementation.
      refute_equal @subject::PINK, "pink"
    end

    class OtherColor < Shy::Enum::Base
      PINK = new

      freeze
    end

    class IntegerSubject < Shy::Enum::Base
      ONE = new(1)

      freeze
    end

    def test_to_s_returns_a_string_with_integer_value
      assert_kind_of String, IntegerSubject::ONE.to_s
    end
  end
end
