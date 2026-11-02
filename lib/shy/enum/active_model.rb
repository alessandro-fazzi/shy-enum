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
    # activemodel). The gem itself has no Rails dependency.
    #
    # The type is registered as `:shy_enum`. It casts a member or a value to the
    # member, and serializes the member to its `value`.
    #
    # ```ruby
    # class PostFilter
    #   include ActiveModel::Model
    #   include ActiveModel::Attributes
    #
    #   attribute :status, :shy_enum, enum_class: Status
    # end
    #
    # PostFilter.new(status: "published").status #=> #<Status::Published value="published">
    # ```
    #
    # See the [Rails guide](rdoc-ref:RAILS.md@activemodel) for how to use it: validation,
    # strict mode and form objects.
    class ActiveModelType < ::ActiveModel::Type::Value
      # The enum class this type casts to
      attr_reader :enum_class

      # * `enum_class` - A subclass of Shy::Enum::Base
      # * `strict` - Raise `ArgumentError` on assignment of an unknown value.
      #   Defaults to `false`
      #
      # Raises `ArgumentError` if `enum_class` is not a subclass of Shy::Enum::Base,
      # or on any other option: the type has no precision, limit or scale.
      def initialize(enum_class:, strict: false)
        unless enum_class.is_a?(Class) && enum_class < Shy::Enum::Base
          raise ArgumentError, "enum_class must be a subclass of Shy::Enum::Base, got #{enum_class.inspect}"
        end

        @enum_class = enum_class
        @strict = strict
        super()
      end

      # Returns `:shy_enum`
      def type = :shy_enum

      # Whether an unknown value raises `ArgumentError` on assignment
      def strict? = @strict

      # Returns the member for `value`, `nil` for a blank value, or `value`
      # itself if there is no member.
      #
      # The lookup goes through Base.[], so it's by value and the enum's
      # `before_cast` applies; labels and Symbols are not looked up. An unknown
      # value is kept so that validations can handle it: the type adds none.
      def cast_value(value) = enum_class[value] || value.presence

      # Returns the `value` of the member that `value` is or looks up to, or
      # `value` unchanged if there is no such member.
      #
      # The lookup matters for queries: ActiveRecord's `where` passes the raw
      # value to `serialize` without casting it first, so this is where
      # `before_cast` gets applied to it. Assignment casts before serializing,
      # so a value reaching the database from a record is already a member.
      #
      # ```ruby
      # # with `before_cast` converting Strings to Integers
      # type = Shy::Enum::ActiveModelType.new(enum_class: Priority)
      # type.serialize(Priority::High) #=> 1
      # type.serialize("1")            #=> 1
      # type.serialize("abc")          #=> "abc"
      # ```
      #
      # Raises Error if `value` is a member of another enum: the database
      # adapter would fail with an unclear `TypeError` otherwise.
      def serialize(value)
        return value.value if value.is_a?(enum_class)

        if value.is_a?(Shy::Enum::Base)
          raise Shy::Enum::Error, "Can't serialize #{value.inspect}: it is not a member of #{enum_class}"
        end

        member = enum_class[value]
        member ? member.value : value
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

      # With `strict`, raises `ArgumentError` if `value` is not blank and matches no member
      #
      # Returns `nil` when `value` is valid, like `ActiveModel::Type::Value`.
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

      private

      # Blank values are valid, like in Rails' `enum`; any other must be a member
      # or the value of a member, after `before_cast`.
      def valid_value?(value) = value.blank? || !enum_class[value].nil?
    end
  end
end

ActiveModel::Type.register(:shy_enum, Shy::Enum::ActiveModelType)
