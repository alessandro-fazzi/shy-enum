# frozen_string_literal: true

require "test_helper"

module Shy
  class ColorEnumTest < Minitest::Test
    class Subject < Shy::Enum::Base
      Pink = new
      Red = new
      Violet = new

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
      assert_operator @subject::Pink, :<, @subject::Red
      assert_operator @subject::Pink, :<, @subject::Violet
      assert_operator @subject::Red, :>, @subject::Pink
      assert_operator @subject::Red, :<, @subject::Violet
      assert_operator @subject::Violet, :>, @subject::Pink
      assert_operator @subject::Violet, :>, @subject::Red
    end

    def test_spaceship_operator_returns_ordinal_comparison
      assert_equal(-1, @subject::Pink <=> @subject::Red)
      assert_equal(0, @subject::Pink <=> @subject::Pink) # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
      assert_equal(1, @subject::Violet <=> @subject::Red)
    end

    def test_enum_is_sortable
      assert_equal [@subject::Pink, @subject::Red, @subject::Violet],
                   [@subject::Violet, @subject::Pink, @subject::Red].sort
    end

    def test_spaceship_operator_returns_nil_when_other_is_not_comparable
      assert_nil(@subject::Pink <=> "not an enum")
    end

    def test_enum_registry
      assert_equal [@subject::Pink, @subject::Red, @subject::Violet], @subject.all
      assert_kind_of Array, @subject.registry
    end

    def test_registry_and_all_are_aliases
      assert_equal @subject.all, @subject.registry
    end

    def test_each_yields_members_in_declaration_order
      yielded = []
      @subject.each { yielded << it } # rubocop:disable Style/MapIntoArray

      assert_equal [@subject::Pink, @subject::Red, @subject::Violet], yielded
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
      assert_equal %w[Pink Red Violet], @subject.map(&:name)
      assert_equal(@subject::Red, @subject.find { it.value == "red" })
      assert_equal @subject::Violet, @subject.max
    end

    def test_enumerable_does_not_leak_members_between_subclasses
      assert_equal %w[pink red violet yellow orange], SubjectSubclass.map(&:value)
      assert_equal %w[pink red violet], Subject.map(&:value)
    end

    def test_include_keeps_module_semantics
      assert Subject.include?(Comparable) # rubocop:disable Minitest/AssertIncludes
      error = assert_raises(TypeError) { Subject.include?(Subject::Pink) }
      assert_match(/member\?/, error.message)
    end

    # RuboCop suggests assert_includes, which relies on `include?`: on enums it
    # checks for included modules, so `member?` must be asserted directly.
    # rubocop:disable Minitest/AssertIncludes, Minitest/RefuteIncludes
    def test_member_with_a_member
      assert Subject.member?(Subject::Pink)
    end

    def test_member_with_a_member_of_a_subclass
      refute Subject.member?(SubjectSubclass::Yellow)
    end

    def test_member_with_a_value
      assert Subject.member?("pink")
      refute Subject.member?("brown")
    end

    def test_member_with_a_member_of_another_enum_sharing_a_value
      refute Subject.member?(OtherColor::Pink)
    end
    # rubocop:enable Minitest/AssertIncludes, Minitest/RefuteIncludes

    def test_enum_values
      assert_equal %w[pink red violet], @subject.values
    end

    def test_exception_when_member_added_to_frozen_enum
      error = assert_raises Shy::Enum::Error do
        @subject.send(:new, :Foo)
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
        @subject::Pink.instance_variable_set(:@value, "Hacked")
      end
    end

    def test_brackets_with_a_member
      assert_same @subject::Pink, @subject[@subject::Pink]
    end

    def test_brackets_with_a_member_of_a_subclass
      assert_nil @subject[SubjectSubclass::Yellow]
    end

    def test_brackets_with_a_value
      assert_same @subject::Pink, @subject["pink"]
    end

    def test_brackets_with_a_member_of_another_enum_sharing_a_value
      assert_nil @subject[OtherColor::Pink]
    end

    def test_brackets_do_not_look_up_by_name
      assert_equal "Pink", @subject::Pink.name
      assert_nil @subject[:Pink]
      assert_nil @subject["Pink"]
    end

    def test_brackets_compare_values_strictly
      assert_same IntegerSubject::One, IntegerSubject[1]
      assert_nil IntegerSubject["1"]
    end

    def test_fetch_with_a_member_or_a_value
      assert_same @subject::Pink, @subject.fetch(@subject::Pink)
      assert_same @subject::Pink, @subject.fetch("pink")
    end

    def test_brackets_return_nil_when_not_found
      assert_nil @subject["brown"]
    end

    def test_fetch_raises_with_the_looked_up_value
      error = assert_raises(Shy::Enum::Error) { IntegerSubject.fetch("1") }
      assert_equal 'Unknown member for value "1"', error.message
    end

    def test_cast_is_an_alias_of_fetch
      assert_equal @subject.method(:fetch), @subject.method(:cast)
    end

    class CastingSubject < Shy::Enum::Base
      One = new(1)

      def self.before_cast(obj) = Integer(obj, exception: false)
      private_class_method :before_cast

      freeze
    end

    def test_before_cast_converts_the_looked_up_value
      assert_same CastingSubject::One, CastingSubject["1"]
    end

    def test_before_cast_is_not_applied_to_members
      assert_same CastingSubject::One, CastingSubject[CastingSubject::One]
    end

    def test_fetch_reports_the_value_before_cast
      error = assert_raises(Shy::Enum::Error) { CastingSubject.fetch("2") }
      assert_equal 'Unknown member for value "2"', error.message
    end

    def test_member_applies_before_cast
      assert CastingSubject.member?("1") # rubocop:disable Minitest/AssertIncludes
    end

    def test_before_cast_is_private
      assert_raises(NoMethodError) { @subject.before_cast("pink") }
    end

    class AttributesSubject < Shy::Enum::Base
      attr_reader :upcased_hex

      def after_initialize
        @upcased_hex = hex&.upcase
      end

      Red = new(hex: "ff0000", complementary: "00ffff")
      Green = new("verde", hex: "00ff00")
      Blue = new

      freeze
    end

    def test_kwargs_define_attribute_readers
      assert_equal "ff0000", AttributesSubject::Red.hex
      assert_equal "00ffff", AttributesSubject::Red.complementary
    end

    def test_member_without_an_attribute_returns_nil
      assert_nil AttributesSubject::Green.complementary
      assert_nil AttributesSubject::Blue.hex
    end

    def test_value_is_positional_alongside_kwargs
      assert_equal "red", AttributesSubject::Red.value
      assert_equal "verde", AttributesSubject::Green.value
    end

    def test_attributes_are_set_before_after_initialize
      assert_equal "00FF00", AttributesSubject::Green.upcased_hex
    end

    def test_attributes_shared_by_members_do_not_redefine_the_reader
      verbose = $VERBOSE
      # Redefining a method warns only in verbose mode
      $VERBOSE = true

      assert_silent do
        OpenEnum.const_set(:SharedOne, OpenEnum.send(:new, shared: 1))
        OpenEnum.const_set(:SharedTwo, OpenEnum.send(:new, shared: 2))
      end
      assert_equal 2, OpenEnum::SharedTwo.shared
    ensure
      $VERBOSE = verbose
    end

    def test_exception_when_attribute_conflicts_with_an_existing_method
      error = assert_raises(Shy::Enum::Error) { OpenEnum.send(:new, name: "foo") }
      assert_equal "`name` is a reserved method and can't be overridden by an attribute reader", error.message
      error = assert_raises(Shy::Enum::Error) { OpenEnum.send(:new, hash: 1) }
      assert_equal "`hash` is a reserved method and can't be overridden by an attribute reader", error.message
    end

    def test_exception_when_attribute_conflicts_with_a_private_method_of_base
      error = assert_raises(Shy::Enum::Error) { OpenEnum.send(:new, initialize: 1) }
      assert_equal "`initialize` is a reserved method and can't be overridden by an attribute reader", error.message
    end

    def test_attribute_can_shadow_a_private_kernel_method
      assert OpenEnum.private_method_defined?(:format)
      assert_equal Kernel, OpenEnum.instance_method(:format).owner

      OpenEnum.const_set(:Formatted, OpenEnum.send(:new, format: "png"))

      assert_equal "png", OpenEnum::Formatted.format
    end

    def test_unrelated_constant_added_to_enum_is_ignored
      OpenEnum.const_set(:Unrelated, "just a string")

      refute_includes OpenEnum.registry.map(&:name), "Unrelated"
    end

    def test_exception_when_duplicated_member_by_const_added
      OpenEnum.const_set(:Foo, OpenEnum.send(:new))
      warning_message = /warning: already initialized constant Shy::ColorEnumTest::OpenEnum::Foo/
      error = nil

      assert_output(nil, warning_message) do
        error = assert_raises Shy::Enum::Error do
          OpenEnum.const_set(:Foo, OpenEnum.send(:new))
        end
      end
      assert_equal "Duplicated member", error.message
    end

    def test_exception_when_duplicated_member_by_value_added
      OpenEnum.const_set(:Bar, OpenEnum.send(:new, 0))

      error = assert_raises Shy::Enum::Error do
        OpenEnum.const_set(:Baz, OpenEnum.send(:new, 0))
      end
      assert_equal "Duplicated member", error.message
    end

    def test_enum_name_property
      assert_equal "Pink", @subject::Pink.name
      assert_equal "Red", @subject::Red.name
      assert_equal "Violet", @subject::Violet.name
    end

    def test_enum_in_case_statement
      result = case @subject::Red
               when @subject::Pink then "pink"
               when @subject::Red then "red"
               when @subject::Violet then "violet"
               end

      assert_equal "red", result
    end

    def test_enum_in_pattern_matching
      result = case @subject::Violet
               in Subject::Pink then "pink"
               in Subject::Red then "red"
               in Subject::Violet then "violet"
               end

      assert_equal "violet", result
    end

    class SubjectSubclass < Subject
      Yellow = new
      Orange = new

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
      assert_equal '#<Shy::ColorEnumTest::Subject::Pink value="pink">', @subject::Pink.inspect
    end

    def test_inspect_shows_the_value_type
      # integer is not represented as string
      assert_equal "#<Shy::ColorEnumTest::IntegerSubject::One value=1>", IntegerSubject::One.inspect
    end

    def test_inspect_shows_the_instance_variables_of_the_member
      assert_equal '#<Shy::ColorEnumTest::AttributesSubject::Green value="verde", hex="00ff00", upcased_hex="00FF00">',
                   AttributesSubject::Green.inspect
    end

    class QuietSubject < Shy::Enum::Base
      Secret = new(token: "abc")

      private

      def instance_variables_to_inspect = %i[@value]

      freeze
    end

    def test_inspect_honors_instance_variables_to_inspect
      assert_equal '#<Shy::ColorEnumTest::QuietSubject::Secret value="secret">', QuietSubject::Secret.inspect
    end

    def test_member_prints_its_value_when_converted_to_string
      assert_equal "pink", @subject::Pink.to_s
    end

    def test_equality_with_other_type_returns_false
      # Order of the compared objects is strict: swapping the two would exercise
      # `String#==` instead of our implementation.
      refute_equal @subject::Pink, "pink"
    end

    class OtherColor < Shy::Enum::Base
      Pink = new

      freeze
    end

    class IntegerSubject < Shy::Enum::Base
      One = new(1)

      freeze
    end

    def test_to_s_returns_a_string_with_integer_value
      assert_kind_of String, IntegerSubject::One.to_s
    end
  end
end
