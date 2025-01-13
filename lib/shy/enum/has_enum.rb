# frozen_string_literal: true

module Shy
  module Enum
    # # Mixin to add enum support to a class
    #
    # This module provides functionality to add enum-like behavior to Ruby classes.
    # When included, it allows classes to define and work with strongly-typed enumerated values
    # in a type-safe manner.
    #
    # ## Features
    #
    # * Type-safe enum values
    # * Auto-generated predicate methods (e.g., `draft?`)
    # * Auto-generated setter methods (e.g., `draft!`)
    # * Proper type checking for assignments
    #
    # ## Example
    #
    # ```ruby
    # class Status < Shy::Enum::Base
    #   DRAFT = new
    #   PUBLISHED = new
    #   ARCHIVED = new
    #   freeze
    # end
    #
    # class Post
    #   include Shy::Enum::HasEnum
    #   enum Status
    # end
    #
    # post = Post.new
    # post.status = Status::DRAFT      # Sets status using regular assignment
    # post.draft?                      # => true
    # post.published?                  # => false
    # post.published!                  # Changes status to PUBLISHED
    # post.published?                  # => true
    #
    # # Type safety
    # post.status = "DRAFT"           # Raises Error: Type error. Enum must be a Status
    # ```
    #
    # ## Generated Methods
    #
    # For each enum value, the following methods are automatically generated:
    #
    # * `value?` - Predicate method that returns true if the enum matches the value
    # * `value!` - Setter method that changes the enum to the specified value
    # * getter method - Returns the current enum value
    # * setter method - Sets the enum value with type checking
    #
    # Example using generated methods:
    # ```ruby
    # post.draft?      # Check if status is draft
    # post.draft!      # Set status to draft
    # post.status      # Get current status
    # post.status = Status::PUBLISHED  # Set status with type checking
    # ```
    module HasEnum
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
      end

      module ClassMethods # :nodoc:
        def enum(klass)
          ivar_name = :"@#{demodulize(klass)}_enum"
          define_enum_getter(klass, ivar_name)
          define_enum_setter(klass, ivar_name)
          define_enum_methods(klass, ivar_name)
        end

        private

        # :nodoc:
        def demodulize(klass)
          klass.name[(klass.name.rindex("::")&.+(2) || 0)..].downcase
        end

        # :nodoc:
        def define_enum_getter(klass, ivar_name)
          define_method(demodulize(klass)) do
            instance_variable_get(ivar_name)
          end
        end

        # :nodoc:
        def define_enum_setter(klass, ivar_name)
          define_method("#{demodulize(klass)}=") do |type_to_set|
            raise(Error, "Type error. Enum type must be a #{klass}") unless type_to_set.is_a?(klass)

            instance_variable_set(ivar_name, type_to_set)
          end
        end

        # :nodoc:
        def define_enum_methods(klass, ivar_name)
          klass.registry.each do |type|
            define_method("#{type.value}!") do
              instance_variable_set(ivar_name, type)
            end

            define_method("#{type.value}?") do
              instance_variable_get(ivar_name) == type
            end
          end
        end
      end
    end
  end
end
