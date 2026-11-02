# frozen_string_literal: true

require_relative "test_helper"

module Shy
  class ActiveModelTypeTest < Minitest::Test
    class Level < Shy::Enum::Base
      Low = new(1)
      High = new(2)

      def self.before_cast(obj) = Integer(obj, exception: false) || obj
      private_class_method :before_cast

      freeze
    end

    class Other < Shy::Enum::Base
      Published = new

      freeze
    end

    def setup
      @type = Shy::Enum::ActiveModelType.new(enum_class: Status)
    end

    # shy/enum/active_model must not load ActiveRecord
    def test_no_active_record
      refute defined?(::ActiveRecord)
    end

    def test_cast
      assert_equal Status::Published, @type.cast("published")
      assert_equal Status::Published, @type.cast(Status::Published)
      assert_nil @type.cast(nil)
    end

    def test_cast_with_before_cast
      type = Shy::Enum::ActiveModelType.new(enum_class: Level)

      assert_equal Level::High, type.cast("2")
      assert_equal Level::High, type.cast(2)
    end

    def test_unknown_returned_as_is
      anything = Object.new

      assert_equal "unknown", @type.cast("unknown")
      assert_equal anything, @type.cast(anything)
    end

    def test_serialize_deserialize
      assert_equal "published", @type.serialize(Status::Published)
      assert_equal "unknown", @type.serialize("unknown")
      assert_equal Status::Published, @type.deserialize("published")
      assert_nil @type.deserialize(nil)
      assert_equal "unknown", @type.deserialize("unknown")
    end

    def test_strict
      type = Shy::Enum::ActiveModelType.new(enum_class: Status, strict: true)

      assert_raises(ArgumentError) { type.assert_valid_value("unknown") }
      assert_nil type.assert_valid_value("published")
      assert_nil type.assert_valid_value(nil)
      assert_nil @type.assert_valid_value("unknown") # not strict
    end

    def test_valid_value
      type = Shy::Enum::ActiveModelType.new(enum_class: Level)

      assert type.valid_value?(Level::High)
      assert type.valid_value?("2"), "before_cast applies"
      assert type.valid_value?(nil)
      assert type.valid_value?("  ") # blank? same as nil by contract
      refute type.valid_value?("3")
      refute type.valid_value?(Other::Published)
    end

    # Like Rails' enum, any blank value is accepted, whitespace-only Strings included
    def test_strict_accepts_blank_values
      type = Shy::Enum::ActiveModelType.new(enum_class: Status, strict: true)

      ["", "  ", "\n"].each { assert_nil type.assert_valid_value(it) }
    end

    def test_invalid_enum_class
      error = assert_raises(ArgumentError) { Shy::Enum::ActiveModelType.new(enum_class: String) }

      assert_equal "enum_class must be a subclass of Shy::Enum::Base, got String", error.message

      error = assert_raises(ArgumentError) { Shy::Enum::ActiveModelType.new(enum_class: nil) }

      assert_equal "enum_class must be a subclass of Shy::Enum::Base, got nil", error.message
    end

    def test_equality
      assert_equal @type, Shy::Enum::ActiveModelType.new(enum_class: Status)
      refute_equal @type, Shy::Enum::ActiveModelType.new(enum_class: Other)
      refute_equal @type, Shy::Enum::ActiveModelType.new(enum_class: Status, strict: true)
    end

    # A blank string is cast to nil, like Rails' enum
    def test_cast_blank_to_nil
      assert_nil @type.cast("")
      assert_nil Shy::Enum::ActiveModelType.new(enum_class: Status, strict: true).cast("")
    end

    # A member of another enum can't reach the database
    def test_serialize_member_of_other_enum_raises
      error = assert_raises(Shy::Enum::Error) { @type.serialize(Other::Published) }

      assert_equal <<~MESSAGE.chomp, error.message
        Can't serialize #<Shy::ActiveModelTypeTest::Other::Published value="published">: it is not a member of Status
      MESSAGE
    end
  end
end
