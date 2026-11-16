# frozen_string_literal: true

module Shy
  module Enum
    # Plugs an enum into any class, so its instances can hold one of the members.
    #
    # Include the module, then declare each enum with ClassMethods#enum. The
    # instances get a reader and a writer for the current member, plus a
    # predicate and a setter for every member. The methods are documented in
    # HasEnum::ClassMethods.
    #
    # ```ruby
    # class Post
    #   include Shy::Enum::HasEnum
    #
    #   enum Status
    # end
    #
    # post = Post.new
    # post.status = Status::Draft
    # post.draft? #=> true
    # ```
    #
    # Do **not** use it in ActiveRecord models: its `enum` would override Rails'
    # `enum`. Use ActiveRecordEnum instead.
    #
    # See the [README](rdoc-ref:README.md@hasenum) for how to use it: custom accessor
    # names, prefix and suffix, type checks.
    module HasEnum
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
      end

      # Class methods added by including HasEnum.
      module ClassMethods
        # :call-seq:
        #   enum(klass, as: name, prefix: true_or_name, suffix: true_or_name)
        #
        # Declares an attribute holding a member of `klass` and defines its methods.
        # The keywords are all optional and can be combined.
        #
        # * `klass` - The enum, a subclass of Base
        # * `as:` - The name of the reader and the writer, as a Symbol or a String.
        #   Defaults to the enum class name, downcased and without its namespace
        #   (`color` for `Color`, `state` for `Issue::State`)
        # * `prefix:` - Prepended to the names of predicates and setters (`status_draft?`).
        #   `true` uses the accessor name, a String or a Symbol is used as is. Defaults to `nil`
        # * `suffix:` - Appended to the names of predicates and setters (`draft_status?`),
        #   same values as `prefix:`. Defaults to `nil`
        #
        # Defines these instance methods, e.g. for `enum Status`:
        #
        # * reader (`status`) - Returns the current member, `nil` until one is set
        # * writer (`status=`) - Sets the current member; raises Error unless
        #   it gets a member of `klass`
        # * a predicate per member (`draft?`) - Whether it is the current member
        # * a setter per member (`draft!`) - Makes it the current member
        #
        # Predicates and setters are named after the members' values, whatever `as:` is,
        # plus the optional `prefix:` and `suffix:`.
        def enum(klass, as: demodulize(klass), prefix: nil, suffix: nil)
          name = as.to_s
          ivar_name = :"@#{name}_enum"
          define_enum_getter(name:, ivar_name:)
          define_enum_setter(klass:, name:, ivar_name:)
          define_enum_methods(klass:, name:, ivar_name:, prefix:, suffix:)
        end

        private

        def demodulize(klass)
          klass.name[(klass.name.rindex("::")&.+(2) || 0)..].downcase
        end

        def define_enum_getter(name:, ivar_name:)
          define_method(name) do
            instance_variable_get(ivar_name)
          end
        end

        def define_enum_setter(klass:, name:, ivar_name:)
          define_method("#{name}=") do |type_to_set|
            raise(Error, "Type error. Enum type must be a #{klass}") unless type_to_set.is_a?(klass)

            instance_variable_set(ivar_name, type_to_set)
          end
        end

        def define_enum_methods(klass:, name:, ivar_name:, prefix:, suffix:)
          klass.registry.each do |type|
            method_name = enum_method_name(type:, name:, prefix:, suffix:)

            define_method("#{method_name}!") do
              instance_variable_set(ivar_name, type)
            end

            define_method("#{method_name}?") do
              instance_variable_get(ivar_name) == type
            end
          end
        end

        def enum_method_name(type:, name:, prefix:, suffix:)
          head = "#{prefix == true ? name : prefix}_" if prefix
          tail = "_#{suffix == true ? name : suffix}" if suffix
          "#{head}#{type.value}#{tail}"
        end
      end
    end
  end
end
