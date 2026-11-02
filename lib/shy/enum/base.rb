# frozen_string_literal: true

module Shy
  module Enum
    # Base class for enums: subclass it and assign each member to a constant.
    #
    # Each member is a frozen instance of the subclass with a #name (the
    # constant name), a #value and an #ordinal (its position, from 1). Call
    # `freeze` after the last member to close the enum.
    #
    # ## Basic usage
    #
    # The value defaults to the downcased constant name:
    #
    # ```ruby
    # class Status < Shy::Enum::Base
    #   Draft = new
    #   Published = new
    #   Archived = new
    #
    #   freeze
    # end
    #
    # Status::Draft.value #=> "draft"
    # ```
    #
    # ## Custom values
    #
    # Pass the value as the first argument, of any type:
    #
    # ```ruby
    # class Priority < Shy::Enum::Base
    #   Low = new(0)
    #   Medium = new(1)
    #   High = new(2)
    #
    #   freeze
    # end
    # ```
    #
    # ## Extra attributes
    #
    # Keyword arguments become attributes with a reader, like a Struct. Members
    # without an attribute return `nil`.
    #
    # ```ruby
    # class Color < Shy::Enum::Base
    #   Red = new(hex: "ff0000")
    #   Green = new("verde", hex: "00ff00")
    #   Blue = new
    #
    #   freeze
    # end
    #
    # Color::Red.hex   #=> "ff0000"
    # Color::Blue.hex  #=> nil
    # ```
    #
    # ## Working with members
    #
    # * Comparison - members are Comparable by ordinal, only with members of the same enum
    # * Iteration - the enum class is Enumerable over its members, in declaration order
    # * Lookup - ::[], ::fetch (aliased as `cast`) and ::member? find members by member or value
    #
    # ## Customization
    #
    # Define these before calling `freeze`:
    #
    # * #after_initialize - refines each member right after it is built
    # * `before_cast` (private class method) - converts the input of ::[], ::fetch and ::member?
    # * `instance_variables_to_inspect` (private) - chooses what #inspect shows
    #
    # The README has a full guide with examples.
    class Base
      class << self
        include Enumerable

        # All enum members, in declaration order. Same as ::all
        #
        # Once the enum is frozen, it returns the same frozen Array on every
        # call; before, a new Array each time.
        def registry = @registry || index.values

        # Closes the enum: no member can be added after it. It freezes the members
        # lookup too, and caches ::registry and ::values.
        def freeze
          if index
            index.each_key(&:freeze).freeze
            @registry = index.values.freeze
            @values = index.keys.freeze
          end
          super
        end

        # Yields each enum member in declaration order
        #
        # Returns an Enumerator if no block is given
        def each(&)
          return enum_for(__method__) { size } unless block_given?

          index.each_value(&)
          self
        end

        # Returns the number of members
        def size = index.size

        # Checks whether `mod` is included in the enum, like `Module#include?`
        #
        # * `mod` - A Module
        #
        # Enumerable would make it look for members instead: use ::member? for that.
        # Raises TypeError if `mod` is not a Module.
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
        # Looks up like ::[], `before_cast` included.
        def member?(obj) = !self[obj].nil?

        # Returns all enum members, in declaration order
        def all = registry

        # Returns the values of all enum members, in declaration order
        #
        # Once the enum is frozen, it returns the same frozen Array on every
        # call; before, a new Array each time.
        def values = @values || index.keys

        # Finds an enum member by member or value
        #
        # * `obj` - An enum member, or the value of an enum member
        #
        # Instances of the enum are looked up among the members, any other object
        # among the values, after `before_cast`. Values are looked up in a Hash,
        # so they are compared with `eql?`: `"1"` doesn't match `1`, and neither
        # does `1.0`, unless `before_cast` converts it.
        #
        # Returns `nil` if the enum member is not found
        #
        # ```ruby
        # Color["red"]   #=> #<Color::Red value="red">
        # Color["brown"] #=> nil
        # ```
        def [](obj)
          if obj.is_a?(self)
            member = index[obj.value]
            return member if member.equal?(obj)

            return
          end

          index[before_cast(obj)]
        end

        # Finds an enum member by member or value, like ::[]
        #
        # * `obj` - An enum member, or the value of an enum member
        #
        # Raises Error if the enum member is not found
        def fetch(obj) = self[obj] || raise(Error, "Unknown member for value #{obj.inspect}")
        alias cast fetch

        # Called when a class inherits from this class. The subclass gets a copy
        # of the members by value, so it inherits the members of the enum without
        # adding its own to it. The copy is not frozen, so the subclass is open.
        # The cached registry is not copied: it is built when the subclass freezes.
        #
        # * `subclass` - The class that is inheriting from this class
        def inherited(subclass) # :nodoc:
          super
          subclass.instance_variable_set(:@index, (index && index.dup) || {})
        end

        def const_added(name) # :nodoc:
          object = const_get(name, false)

          return unless object.is_a?(self)

          object.name = name.to_s
          object.value ||= name.to_s.downcase

          raise Error, "Duplicated member" if index.key?(object.value)

          object.freeze
          register(object)
        end

        private

        def register(member) = index[member.value] = member

        # The members by value, in declaration order (a Hash keeps the insertion
        # order). The single source of the members: ::[] is a Hash lookup, and
        # ::registry and ::each read from it.
        attr_reader :index

        # :doc:
        # Converts the object looked up by `[]`, `fetch` and `member?` before
        # comparing it with the values. Enum members are not converted.
        #
        # Returns the object unchanged; override it to accept other inputs, e.g.
        # strings for integer values:
        #
        # ```ruby
        # def self.before_cast(obj) = Integer(obj, exception: false)
        # private_class_method :before_cast
        # ```
        def before_cast(obj) = obj
      end

      # The position of the enum member in declaration order, starting from 1
      attr_reader :ordinal
      # The value of the enum member: the first argument of `new`, or the
      # downcased constant name. Members are frozen, so it can't be changed.
      attr_accessor :value
      # The name of the constant holding the enum member, e.g. `"Red"`.
      # Members are frozen, so it can't be changed.
      attr_accessor :name

      # Builds a member. `new` is private: call it only inside the enum body,
      # assigning the result to a constant.
      #
      # * `value` - The member value; defaults to the downcased constant name
      # * `attributes` - Extra attributes, each one gets a reader
      #
      # Raises Error if the enum is frozen, or if an attribute is named like an
      # existing method (e.g. `name`).
      def initialize(value = nil, **attributes)
        raise(Error, "Can't add new values to a closed Enum") if self.class.frozen?

        @value = value
        @ordinal = self.class.size.next
        attributes.each { |key, attribute| define_attribute(key, attribute) }
        after_initialize
      end

      # Called at the end of `initialize`. Override it to refine each member,
      # with no need to call `super` or to override `initialize`.
      #
      # The extra attributes, the positional value and the ordinal are already
      # set; the name and the default value are not, as they are assigned when
      # the constant is defined. The member is not frozen yet.
      #
      # Define it before the members: the ones declared above it won't call it.
      def after_initialize; end

      private_class_method :new

      # Returns the value as a String, e.g. `"1"` for a value of `1`
      def to_s = value.to_s

      # Returns a string representation of the enum member, with its value and
      # extra attributes, e.g. `#<Color::Red value="red", hex="ff0000">`
      #
      # Override the private `instance_variables_to_inspect` to choose the
      # instance variables to show.
      def inspect
        fields = instance_variables_to_inspect.map do |ivar|
          "#{ivar.to_s.delete_prefix("@")}=#{instance_variable_get(ivar).inspect}"
        end
        "#<#{self.class}::#{name} #{fields.join(", ")}>"
      end

      # Compares enum members based on their ordinal position
      #
      # Returns `nil` if `other` is not a member of the same enum
      #
      # ```ruby
      # Status::Draft < Status::Published #=> true
      # Status::Draft <=> "draft"         #=> nil
      # ```
      def <=>(other) = other.is_a?(self.class) ? ordinal <=> other.ordinal : nil
      include Comparable

      private

      # The instance variables shown by #inspect: all but `@name` and `@ordinal`.
      # Override it to choose what to show.
      def instance_variables_to_inspect = instance_variables - %i[@name @ordinal]

      def define_attribute(key, attribute)
        if Base.method_defined?(key) || Base.private_method_defined?(key, false)
          raise(Error, "`#{key}` is a reserved method and can't be overridden by an attribute reader")
        end

        self.class.attr_reader(key) unless self.class.method_defined?(key)
        instance_variable_set(:"@#{key}", attribute)
      end
    end
  end
end
