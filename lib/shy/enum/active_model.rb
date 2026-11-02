# frozen_string_literal: true

require "shy/enum"

begin
  require "active_model"
rescue LoadError => e
  raise LoadError,
        "shy/enum/active_model requires the activemodel gem (#{Shy::Enum::RAILS_REQUIREMENT}): #{e.message}"
end

unless Gem::Requirement.new(Shy::Enum::RAILS_REQUIREMENT).satisfied_by?(ActiveModel.gem_version)
  raise LoadError, "shy/enum/active_model requires activemodel #{Shy::Enum::RAILS_REQUIREMENT}, " \
                   "found #{ActiveModel.gem_version}"
end

module Shy
  module Enum
    # ActiveModel attribute type for Shy::Enum enums. Opt-in: it is not loaded by
    # `require "shy/enum"`, load it with `require "shy/enum/active_model"` (needs
    # activemodel ~> 8.1). The gem itself has no Rails dependency.
    #
    # The type is registered as `:shy_enum`. It casts a value or a member to the
    # member, and serializes the member to its `value`.
    #
    # ```ruby
    # require "shy/enum/active_model"
    #
    # class Post
    #   include ActiveModel::Model
    #   include ActiveModel::Attributes
    #
    #   attribute :status, :shy_enum, enum_class: Status, default: Status::Draft
    #   validates :status, inclusion: { in: Status.all }
    # end
    #
    # Post.new(status: "published").status #=> #<Status::Published value="published">
    # ```
    #
    # * Lookup - uses Base.[], so it's by value and `before_cast` applies: define
    #   it on the enum to cast e.g. `"1"` to `1` for string columns holding
    #   integer values. Labels and Symbols are not looked up
    # * Casting - an unknown value is returned as is, so validations can handle
    #   it; a blank value (e.g. `""`) becomes `nil`. No validation is added:
    #   write it yourself, with `in: Status.all`
    # * Strict mode - off by default. With `strict: true` an unknown value raises
    #   `ArgumentError` on assignment; blank values (`nil`, `""`, `"  "`) don't
    #   raise: `attribute :status, :shy_enum, enum_class: Status, strict: true`
    # * Deserializing - an unknown value is returned as is. See #deserialize
    class ActiveModelType < ::ActiveModel::Type::Value
      # The enum class this type casts to
      attr_reader :enum_class

      # * `enum_class` - A subclass of Base
      # * `strict` - Raise `ArgumentError` on assignment of an unknown value.
      #   Defaults to `false`
      #
      # Raises `ArgumentError` if `enum_class` is not a subclass of Base.
      def initialize(enum_class:, strict: false, **)
        unless enum_class.is_a?(Class) && enum_class < Shy::Enum::Base
          raise ArgumentError, "enum_class must be a subclass of Shy::Enum::Base, got #{enum_class.inspect}"
        end

        @enum_class = enum_class
        @strict = strict
        super(**)
      end

      # Returns `:shy_enum`
      def type
        :shy_enum
      end

      # Whether an invalid value (see #valid_value?) raises `ArgumentError` on
      # assignment
      def strict?
        @strict
      end

      # Whether `value` can be assigned. Use it to check an input before assigning
      # it to a strict attribute:
      #
      # ```ruby
      # Post.type_for_attribute(:status).valid_value?(params[:status])
      # ```
      def valid_value?(value)
        value.blank? || !enum_class[value].nil?
      end

      # Returns the member for `value`, `nil` for a blank value, or `value`
      # itself if there is no member
      def cast_value(value)
        enum_class[value] || value.presence
      end

      # Returns the `value` of the member, or `value` unchanged if it is not a member
      #
      # Raises Error if `value` is a member of another enum: the database
      # adapter would fail with an unclear `TypeError` otherwise.
      def serialize(value)
        return value.value if value.is_a?(enum_class)

        if value.is_a?(Shy::Enum::Base)
          raise Shy::Enum::Error, "Can't serialize #{value.inspect}: it is not a member of #{enum_class}"
        end

        value
      end

      # Returns the member for a stored value, `nil` for `nil`, or the value
      # itself if no member has it.
      #
      # It doesn't raise: Rails deserializes for `inspect`, `attributes` and
      # dirty tracking too, so one unknown value would break them all.
      def deserialize(value)
        return if value.nil?

        enum_class[value] || value
      end

      # With `strict`, raises `ArgumentError` if `value` is not #valid_value?
      def assert_valid_value(value)
        return if !strict? || valid_value?(value)

        raise ArgumentError, "'#{value}' is not a valid #{enum_class}"
      end

      def ==(other) # :nodoc:
        super && enum_class == other.enum_class && strict? == other.strict?
      end
      alias eql? ==

      def hash # :nodoc:
        [super, enum_class, strict?].hash
      end
    end
  end
end

ActiveModel::Type.register(:shy_enum, Shy::Enum::ActiveModelType)
