# frozen_string_literal: true

module Shy
  module Enum
    # Plugs an enum into any class, so its instances can hold one of the members.
    #
    # Include the module, then declare each enum with ClassMethods#enum. The
    # instances get a reader and a writer for the current member, plus a
    # predicate and a setter for every member.
    #
    # ## Example
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
    # class Post
    #   include Shy::Enum::HasEnum
    #
    #   enum Status
    # end
    #
    # post = Post.new
    # post.status                    #=> nil
    # post.status = Status::Draft
    # post.draft?                    #=> true
    # post.published?                #=> false
    # post.published!
    # post.status                    #=> #<Status::Published value="published">
    #
    # post.status = "draft"
    # #=> Shy::Enum::Error: Type error. Enum type must be a Status
    # ```
    #
    # ## Custom accessor name
    #
    # Pass `as:` to name the reader and the writer yourself:
    #
    # ```ruby
    # class Post
    #   include Shy::Enum::HasEnum
    #
    #   enum Status, as: :state
    # end
    #
    # post = Post.new
    # post.state = Status::Draft
    # post.state #=> #<Status::Draft value="draft">
    # ```
    module HasEnum
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
      end

      # Class methods added by including HasEnum.
      module ClassMethods
        # :call-seq:
        #   enum(klass)
        #   enum(klass, as: name)
        #
        # Declares an attribute holding a member of `klass` and defines its methods.
        #
        # * `klass` - The enum, a subclass of Base
        # * `as:` - The name of the reader and the writer, as a Symbol or a String.
        #   Defaults to the enum class name, downcased and without its namespace
        #   (`color` for `Color`, `state` for `Issue::State`)
        #
        # Defines these instance methods, e.g. for `enum Status`:
        #
        # * reader (`status`) - Returns the current member, `nil` until one is set
        # * writer (`status=`) - Sets the current member; raises Error unless
        #   it gets a member of `klass`
        # * a predicate per member (`draft?`) - Whether it is the current member
        # * a setter per member (`draft!`) - Makes it the current member
        #
        # Predicates and setters are named after the members' values, whatever `as:` is.
        def enum(klass, as: demodulize(klass))
          name = as.to_s
          ivar_name = :"@#{name}_enum"
          define_enum_getter(name, ivar_name)
          define_enum_setter(klass, name, ivar_name)
          define_enum_methods(klass, ivar_name)
        end

        private

        def demodulize(klass)
          klass.name[(klass.name.rindex("::")&.+(2) || 0)..].downcase
        end

        def define_enum_getter(name, ivar_name)
          define_method(name) do
            instance_variable_get(ivar_name)
          end
        end

        def define_enum_setter(klass, name, ivar_name)
          define_method("#{name}=") do |type_to_set|
            raise(Error, "Type error. Enum type must be a #{klass}") unless type_to_set.is_a?(klass)

            instance_variable_set(ivar_name, type_to_set)
          end
        end

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
