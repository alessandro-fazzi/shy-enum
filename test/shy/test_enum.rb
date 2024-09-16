# frozen_string_literal: true

require "test_helper"

class Shy::TestEnum < Minitest::Test # rubocop:disable Style/ClassAndModuleChildren
  def setup
    @subject = Subject.new
  end

  def test_that_it_has_a_version_number
    refute_nil ::Shy::Enum::VERSION
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
    assert_equal "Type error. Enum type must be of the same class", error.message
  end

  def test_setting_enum_with_bang_method
    @subject.pink!

    assert_equal Color::PINK, @subject.color
  end

  def test_checking_enum_with_predicate_method
    @subject.pink!

    assert_predicate @subject, :pink?
  end

  def test_enum_comparisons
    assert_operator Color::PINK, :<, Color::RED
    assert_operator Color::PINK, :<, Color::VIOLET
    assert_operator Color::RED, :>, Color::PINK
    assert_operator Color::RED, :<, Color::VIOLET
    assert_operator Color::VIOLET, :>, Color::PINK
    assert_operator Color::VIOLET, :>, Color::RED
  end

  def test_enum_registry
    assert_equal [Color::PINK, Color::RED, Color::VIOLET], Color.registry.to_a
    assert_kind_of Set, Color.registry
  end

  def test_enum_can_be_closed
    error = assert_raises Shy::Enum::Error do
      ClosedEnum.send(:t, :FOO)
    end
    assert_equal "Can't add new values to a closed Enum", error.message
  end

  def test_enum_cannot_be_instantiated
    error = assert_raises NoMethodError do
      Shy::Enum::Base.new
    end
    assert_equal "private method `new' called for class Shy::Enum::Base", error.message
  end
end
