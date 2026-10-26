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
    #
    # ## With extra attributes
    #
    # Keyword arguments become attributes with a reader, like a Struct. Members
    # without an attribute return nil.
    #
    # ```
    # class Color < Shy::Enum::Base
    #   RED = new(hex: "ff0000")
    #   GREEN = new("verde", hex: "00ff00")
    #   freeze
    # end
    #
    # Color::RED.hex #=> "ff0000"
    # ```
    class Base
      class << self
        include Enumerable

        # All enum members (aliased as `all`)
        attr_reader :registry

        # Yields each enum member in declaration order
        #
        # Returns an Enumerator if no block is given
        def each(&)
          return enum_for(__method__) { size } unless block_given?

          registry.each(&)
          self
        end

        def size
          registry.size
        end

        # Including Enumerable shadows `Module#include?`: restore the idiomatic
        # Module API, so it keeps checking for included modules and not for members.
        def include?(mod)
          unless mod.is_a?(Module)
            raise TypeError, "wrong argument type #{mod.class} (expected Module). " \
                             "Use `member?` to check for enum members or values"
          end

          Module.instance_method(:include?).bind_call(self, mod)
        end

        # Checks whether the enum contains the given member or value
        #
        # * `obj` - An enum member, or the value of an enum member
        #
        # Instances of the enum are looked up among the members, any other object
        # among the values.
        def member?(obj)
          return super if obj.is_a?(self)

          values.include?(obj)
        end

        # Returns the complete registry of entries
        def all
          registry
        end

        # Returns all enum values
        def values
          all.map(&:value)
        end

        # Finds an enum member by member or value
        #
        # * `obj` - An enum member, or the value of an enum member
        #
        # Instances of the enum are looked up among the members, any other object
        # among the values.
        #
        # Returns nil if the enum member is not found
        def [](obj)
          return find { it == obj } if obj.is_a?(self)

          value = before_cast(obj)
          find { it.value == value }
        end

        # Finds an enum member by member or value, like `[]`
        #
        # * `obj` - An enum member, or the value of an enum member
        #
        # Raises Error if the enum member is not found
        def fetch(obj)
          self[obj] || raise(Error, "Unknown member for value #{obj.inspect}")
        end
        alias cast fetch

        # Called when a class inherits from this class. Ensures the registry of enum values
        # is properly copied to the subclass to maintain independent registries for each
        # enum class hierarchy.
        #
        # * `subclass` - The class that is inheriting from this class
        def inherited(subclass) # :nodoc:
          super
          subclass.instance_variable_set(:@registry, (registry && registry.dup) || [])
        end

        def const_added(name) # :nodoc:
          object = const_get(name, false)

          return unless object.is_a?(self)

          object.name = name.to_s
          object.value ||= name.to_s.downcase

          raise Error, "Duplicated member" if registry.find { it.value == object.value }

          object.freeze

          registry << object
        end

        private

        # Converts the object looked up by `[]` and `fetch` before comparing it
        # with the values. Enum members are not converted.
        #
        # Returns the object unchanged; override it to accept other inputs, e.g.
        # strings for integer values:
        #
        # ```
        # def self.before_cast(obj) = Integer(obj, exception: false)
        # private_class_method :before_cast
        # ```
        def before_cast(obj)
          obj
        end
      end

      # The ordinal position of the enum member
      attr_reader :ordinal
      # The value of the enum member
      attr_accessor :value
      # The name of the enum member
      attr_accessor :name

      def initialize(value = nil, **attributes)
        raise(Error, "Can't add new values to a closed Enum") if self.class.frozen?

        @value = value
        @ordinal = self.class.registry.size.next
        attributes.each { |key, attribute| define_attribute(key, attribute) }
        after_initialize
      end

      # Called after initialization. Override in subclasses to refine you initialization
      # without the need to handle calling `super`. Extra attributes are already set.
      def after_initialize; end

      private_class_method :new

      # Returns the value as a string
      def to_s
        value.to_s
      end

      # Returns a string representation of the enum member
      def inspect
        "#{self.class}::#{name}"
      end

      # Compares enum members based on their ordinal position
      #
      # Returns nil if the other object is not comparable
      def <=>(other)
        return nil unless other.is_a?(self.class)

        ordinal <=> other.ordinal
      end
      include Comparable

      private

      def define_attribute(key, attribute)
        if Base.method_defined?(key) || Base.private_method_defined?(key, false)
          raise(Error, "Attribute `#{key}` conflicts with #{Base.instance_method(key).owner}##{key}")
        end

        self.class.attr_reader(key) unless self.class.method_defined?(key)
        instance_variable_set(:"@#{key}", attribute)
      end
    end
  end
end
