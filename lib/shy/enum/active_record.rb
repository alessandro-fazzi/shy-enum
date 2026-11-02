# frozen_string_literal: true

require "shy/enum/active_model"

begin
  require "active_record"
rescue LoadError => e
  raise LoadError,
        "shy/enum/active_record requires the activerecord gem (#{Shy::Enum::RAILS_REQUIREMENT}): #{e.message}"
end

unless Gem::Requirement.new(Shy::Enum::RAILS_REQUIREMENT).satisfied_by?(ActiveRecord.gem_version)
  raise LoadError, "shy/enum/active_record requires activerecord #{Shy::Enum::RAILS_REQUIREMENT}, " \
                   "found #{ActiveRecord.gem_version}"
end

ActiveRecord::Type.register(:shy_enum, Shy::Enum::ActiveModelType)

module Shy
  module Enum
    # Opt-in ActiveRecord integration: `require "shy/enum/active_record"` (needs
    # activerecord), then include this module in a model or in
    # `ApplicationRecord`. Nothing is hooked in automatically.
    #
    # It adds the ClassMethods#shy_enum macro, modeled on Rails' `enum`: the
    # attribute is stored as the member `value` and read back as the member.
    #
    # ```ruby
    # class Post < ApplicationRecord
    #   include Shy::Enum::ActiveRecordEnum
    #
    #   shy_enum :status, Status
    # end
    #
    # Post.create!(status: "published").status #=> #<Status::Published value="published">
    # ```
    #
    # The require also loads ActiveModelType and registers it as `:shy_enum` in
    # `ActiveRecord::Type`.
    #
    # Don't include HasEnum in ActiveRecord models: its `enum` would override
    # Rails' `enum`.
    #
    # See the [Rails guide](rdoc-ref:RAILS.md@activerecord) for how to use it: generated
    # methods, forms, validation and how it differs from Rails' `enum`.
    module ActiveRecordEnum
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
      end

      # Class methods added to the including model
      module ClassMethods
        # Declares an enum attribute, stored as the member `value` and read back
        # as the member. Assignment and `where` take members and values, looked
        # up with `enum_class[]`; labels and Symbols are not looked up.
        #
        # * `name` - The attribute name
        # * `enum_class` - A subclass of Base
        # * `prefix`, `suffix` - Added to the generated method and scope names,
        #   like in Rails' `enum`. `true` uses the attribute name, a String or
        #   Symbol is used as is. Default `nil`
        # * `scopes` - Define the `<label>` and `not_<label>` scopes, like Rails'
        #   `enum`. Default `true`
        # * `instance_methods` - Define `<label>?` and `<label>!`, like Rails'
        #   `enum`. Default `true`
        # * `validate` - Default `false`: the attribute is strict, an unknown
        #   value raises `ArgumentError` on assignment, like Rails' `enum`. With
        #   `true` or a Hash of options for `validates_inclusion_of`, the
        #   inclusion validation is added instead, like Rails' `enum`.
        #   **Deviation**: `nil` is valid unless the Hash has `allow_nil: false`
        # * `default` - The default of the attribute, e.g. `Status::Draft`; if not
        #   given, the attribute has the default of the column
        #
        # The label of a member is `member.name.underscore` (`InProgress` gives
        # `in_progress`). It names the generated methods, scopes and keys, and is
        # never stored.
        #
        # The generated instance methods live in a module included in the model,
        # so the model can override them and call `super`.
        #
        # It also defines the class method `name.pluralize` (e.g. `Post.statuses`),
        # returning a frozen `HashWithIndifferentAccess` of labels and members,
        # like Rails' `enum`. The labels ignore `prefix` and `suffix`, as in Rails.
        #
        # The reader returns the member, and raises Error on a value read from the
        # database that matches no member (**Deviation**: Rails' `enum` returns
        # `nil`): the type can't raise there, see ActiveModelType#deserialize.
        #
        # Raises Error if two members have the same label (e.g. `HTTP` and `Http`,
        # both `http`), or if a generated name is taken: an instance method
        # already defined in the model, or a class method or scope already
        # defined or that Rails considers dangerous. A class method the model only
        # inherits from `Object` (e.g. `Kernel#open`) is not a conflict, as in
        # Rails' `enum`.
        #
        # Raises `ArgumentError` on any other option, like Rails' `enum`.
        def shy_enum(name, enum_class, default: (no_default_provided = true), prefix: nil, suffix: nil, # rubocop:disable Metrics/ParameterLists
                     scopes: true, instance_methods: true, validate: false)
          name = name.to_sym
          labels = enum_class.all.to_h { [it, shy_enum_method_name(it, name, prefix, suffix)] }
          shy_enum_check_conflicts(name, labels, scopes, instance_methods)

          # `attribute` tells "no default" from `default: nil`, so forward it only if given
          attribute_options = no_default_provided ? {} : { default: default }
          attribute name, :shy_enum, enum_class: enum_class, strict: !validate, **attribute_options
          shy_enum_define_reader(name, enum_class)
          shy_enum_define_instance_methods(name, labels) if instance_methods
          shy_enum_define_scopes(name, labels) if scopes
          shy_enum_define_class_reader(name, enum_class)
          shy_enum_define_validation(name, enum_class, validate) if validate
        end

        private

        def shy_enum_define_validation(name, enum_class, validate)
          options = validate.is_a?(Hash) ? validate : {}
          validates_inclusion_of name, in: enum_class.all, allow_nil: true, **options
        end

        def shy_enum_method_name(member, name, prefix, suffix)
          prefix = "#{prefix == true ? name : prefix}_" if prefix
          suffix = "_#{suffix == true ? name : suffix}" if suffix
          "#{prefix}#{member.name.underscore}#{suffix}"
        end

        def shy_enum_check_conflicts(name, labels, scopes, instance_methods)
          shy_enum_check_duplicate_labels(labels)
          instance = []
          klass = [name.to_s.pluralize]
          labels.each_value do |label|
            instance.push("#{label}?", "#{label}!") if instance_methods
            klass.push(label, "not_#{label}") if scopes
          end

          instance.each { shy_enum_conflict!(it, "an instance method") if shy_enum_instance_method_conflict?(it) }
          klass.each { shy_enum_conflict!(it, "a class method or scope") if shy_enum_class_method_conflict?(it) }
        end

        # Two members whose names underscore to the same label (e.g. `HTTP` and
        # `Http`) would overwrite each other's methods, scopes and key in the
        # class reader Hash.
        def shy_enum_check_duplicate_labels(labels)
          labels.group_by { |_member, label| label }.each do |label, pairs|
            next if pairs.one?

            names = pairs.map { |member, _label| member.name }.join(" and ")
            raise Shy::Enum::Error, "Can't define `#{label}`: members #{names} have the same label"
          end
        end

        # Like Rails' `enum`: a method inherited from Object (e.g. Kernel#open) is
        # not a conflict, unless the model redefines it or Rails restricts it.
        def shy_enum_class_method_conflict?(method)
          return true if dangerous_class_method?(method)
          return false unless respond_to?(method, true)
          return true unless Object.respond_to?(method, true)

          method(method).owner != Object.method(method).owner
        end

        def shy_enum_instance_method_conflict?(method)
          method_defined?(method) || private_method_defined?(method)
        end

        def shy_enum_conflict!(method, kind)
          raise Shy::Enum::Error, "Can't define `#{method}`: #{kind} with that name already exists in #{self}"
        end

        # The reader raises on a value read from the database that is not a
        # member. An unknown value assigned with `validate:` is returned as is,
        # so validations can handle it.
        def shy_enum_define_reader(name, enum_class)
          shy_enum_methods_module.define_method(name) do
            value = read_attribute(name)
            return value if value.nil? || value.is_a?(enum_class) || attribute_changed?(name)

            raise Shy::Enum::Error, "Unknown member for value #{value.inspect} read from the database"
          end
        end

        # Like Rails' `enum`, keyed by label without prefix or suffix
        def shy_enum_define_class_reader(name, enum_class)
          members = enum_class.all.to_h { [it.name.underscore, it] }.with_indifferent_access.freeze
          singleton_class.define_method(name.to_s.pluralize) { members }
        end

        def shy_enum_define_instance_methods(name, labels)
          labels.each do |member, label|
            shy_enum_methods_module.define_method(:"#{label}?") { public_send(name) == member }
            shy_enum_methods_module.define_method(:"#{label}!") { update!(name => member) }
          end
        end

        # The generated instance methods live in a module included in the model,
        # like Rails' `enum` does, so the model can override them and call `super`.
        # One module per model: a subclass calling `shy_enum` gets its own. Its
        # temporary name shows up in `ancestors`, e.g. `Post::ShyEnumMethods(anonymous)`.
        def shy_enum_methods_module
          @shy_enum_methods_module ||= Module.new.tap do |mod|
            mod.set_temporary_name("#{self}::ShyEnumMethods(anonymous)")
            include mod
          end
        end

        def shy_enum_define_scopes(name, labels)
          labels.each do |member, label|
            scope label, -> { where(name => member) }
            scope :"not_#{label}", -> { where.not(name => member) }
          end
        end
      end
    end
  end
end
