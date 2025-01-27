# frozen_string_literal: true

module Shy
  module Enum
    # Base class for creating enums
    #
    # ## Basic usage
    #
    # ```
    # class Status < Shy::Enum::Base
    #   DRAFT = new
    #   PUBLISHED = new
    #   ARCHIVED = new
    #   freeze
    # end
    # ```
    #
    # ## With custom values
    #
    # ```
    # class Role < Shy::Enum::Base
    #   ADMIN = new("administrator")
    #   USER = new("regular_user")
    #   freeze
    # end
    # ```
    #
    # ## With integer values
    #
    # ```
    # class Priority < Shy::Enum::Base
    #   LOW = new(0)
    #   MEDIUM = new(1)
    #   HIGH = new(2)
    #   freeze
    # end
    # ```
    class Base
      class << self
        # All enum members (aliased as `all`)
        attr_reader :registry

        # Returns the complete registry of entries
        def all
          registry
        end

        # Returns all enum values
        def values
          all.map(&:value)
        end

        # Finds an enum member by its name
        #
        # * `name` - The name of the enum member as String or Symbol
        #
        # Raises Error if the enum member is not found
        def [](name)
          const_get(name, false)
        rescue NameError
          raise(Error, "Unknown member")
        end

        def inherited(subclass) # :nodoc:
          super
          subclass.instance_variable_set(:@registry, [])
        end

        def const_added(name) # :nodoc:
          object = const_get(name, false)

          return unless object.is_a?(self)

          object.name = name.to_s
          object.value ||= name.to_s.downcase

          raise Error, "Duplicated member" if registry.find { _1.value == object.value }

          object.freeze

          registry << object
        end
      end

      # The ordinal position of the enum member
      attr_reader :ordinal
      # The value of the enum member
      attr_accessor :value
      # The name of the enum member
      attr_accessor :name

      def initialize(value = nil)
        raise(Error, "Can't add new values to a closed Enum") if self.class.frozen?

        @value = value
        @ordinal = self.class.registry.size.next
        after_initialize
      end

      # Called after initialization. Override in subclasses to refine you initialization
      # without the need to handle calling `super`.
      def after_initialize; end

      private_class_method :new

      # Returns the value as a string
      def to_s
        value
      end

      # Returns a string representation of the enum member
      def inspect
        "#{self.class}::#{name}"
      end

      # Compares enum members based on their ordinal position
      #
      # Raises ArgumentError if the other object is not comparable
      def <=>(other)
        ordinal <=> other.ordinal
      end
      include Comparable
    end
  end
end
