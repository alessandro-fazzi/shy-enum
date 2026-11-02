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
    # activerecord ~> 8.1), then include this module in a model or in
    # `ApplicationRecord`. Nothing is hooked in automatically.
    #
    # The require loads ActiveModelType too and registers it as `:shy_enum` in
    # `ActiveRecord::Type`, so `attribute :status, :shy_enum, enum_class: Status`
    # also works without the macro.
    #
    # It adds the `shy_enum` macro: the attribute is stored as the member `value`
    # and read back as the **member**, not as a label String like Rails' `enum`.
    #
    # ```ruby
    # require "shy/enum/active_record"
    #
    # class Post < ApplicationRecord
    #   include Shy::Enum::ActiveRecordEnum
    #
    #   shy_enum :status, Status, default: Status::Draft
    # end
    #
    # post = Post.create!(status: "published")
    # post.status          #=> #<Status::Published value="published">
    # post.published?      #=> true
    # post.draft!          # updates the record
    # Post.draft           # scope
    # Post.not_draft       # scope
    # Post.where(status: Status::Draft)
    # Post.statuses        #=> {"draft" => #<Status::Draft value="draft">, ...}
    # Post.statuses[:in_progress] #=> #<Status::InProgress value="inprogress">
    # ```
    #
    # The label of each member is `member.name.underscore` (`InProgress` becomes
    # `in_progress`), so it works with Integer values too.
    #
    # ## Parity with Rails' `enum`
    #
    # On purpose, `shy_enum` behaves like Rails' `enum` here:
    #
    # * An unknown value raises `ArgumentError` on assignment (a 500 in a
    #   controller), unless `validate:` turns it into a validation error
    # * With `validate:` the inclusion validation is added for you
    # * Blank values (`nil`, `""`, `"  "`) are cast to `nil` and never raise
    # * `prefix:`, `suffix:`, `scopes:`, `instance_methods:` and the `not_label`
    #   scopes work the same way
    # * The generated methods live in a module included in the model, so they
    #   can be overridden calling `super`
    # * A method inherited from `Object` (e.g. `Kernel#open`) is not a conflict
    # * `Post.statuses` returns a frozen Hash with indifferent access, keyed by
    #   label
    #
    # ## Deviations from Rails' `enum`
    #
    # * The reader returns the member, not a label String
    # * Labels come from `member.name.underscore`, not from the stored values
    # * Assignment takes members and values only, not labels or Symbols:
    #   `Post.new(status: :draft)` raises `ArgumentError`
    # * A value read from the database that matches no member makes the reader
    #   raise Error; Rails' `enum` returns `nil`
    # * With `validate:`, `nil` is valid unless you pass
    #   `validate: { allow_nil: false }`; Rails' `enum` rejects it by default
    # * The values of `Post.statuses` are the members, not the stored values
    # * A conflicting method name raises Error, not `ArgumentError`
    # * Unknown options go to `attribute`; Rails' `enum` raises on them
    #
    # Do **not** use HasEnum in ActiveRecord models: its `enum` would override
    # Rails' `enum`.
    module ActiveRecordEnum
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
      end

      # Class methods added to the including model
      module ClassMethods
        # Declares an enum attribute.
        #
        # * `name` - The attribute name
        # * `enum_class` - A subclass of Base
        # * `prefix`, `suffix` - Added to the generated method names, like in
        #   Rails' `enum`; `true` uses the attribute name
        # * `scopes` - Define `label` and `not_label` scopes, like Rails' `enum`.
        #   Defaults to `true`
        # * `instance_methods` - Define `label?` and `label!`, like Rails' `enum`.
        #   Defaults to `true`
        # * `validate` - Defaults to `false`: the attribute is strict, an unknown
        #   value raises `ArgumentError` on assignment, like Rails' `enum`. With
        #   `true` or a Hash of options for `validates_inclusion_of`, the
        #   inclusion validation is added instead, like Rails' `enum`.
        #   **Deviation**: `nil` is valid unless the Hash has `allow_nil: false`
        # * `attribute_options` - Passed to `attribute`, e.g. `default:`.
        #   **Deviation**: Rails' `enum` raises on unknown options. The type
        #   options `strict:` and `enum_class:` are not accepted: `strict`
        #   follows `validate`, `enum_class` is the second argument
        #
        # It also defines the class method `name.pluralize` (e.g. `Post.statuses`),
        # returning a frozen `HashWithIndifferentAccess` of labels and members,
        # like Rails' `enum`. The labels ignore `prefix` and `suffix`, as in Rails.
        #
        # The reader returns the member, and raises Error on a value read from the
        #  database that matches no member (**NOTE**: Rails' `enum` returns
        #  `nil`): the type can't raise there, see ActiveModelType#deserialize.
        #
        # Raises Error if a generated method, scope or class method already
        # exists, or if two members have the same label (e.g. `HTTP` and `Http`,
        #  both `http`).
        #
        # Raises `ArgumentError` if `attribute_options` contains `strict:` or
        # `enum_class:`: they would silently override the values set by the macro.
        def shy_enum(name, enum_class, prefix: nil, suffix: nil, scopes: true, instance_methods: true, # rubocop:disable Metrics/ParameterLists
                     validate: false, **attribute_options)
          shy_enum_check_attribute_options(attribute_options)
          name = name.to_sym
          labels = enum_class.all.to_h { [it, shy_enum_method_name(it, name, prefix, suffix)] }
          shy_enum_check_conflicts(name, labels, scopes, instance_methods)

          attribute name, :shy_enum, enum_class: enum_class, strict: !validate, **attribute_options
          shy_enum_define_reader(name, enum_class)
          shy_enum_define_instance_methods(name, labels) if instance_methods
          shy_enum_define_scopes(name, labels) if scopes
          shy_enum_define_class_reader(name, enum_class)
          shy_enum_define_validation(name, enum_class, validate) if validate
        end

        private

        # `strict:` and `enum_class:` passed through `**attribute_options` would
        # win over the ones set by shy_enum, without any warning.
        def shy_enum_check_attribute_options(attribute_options)
          if attribute_options.key?(:strict)
            raise ArgumentError, "shy_enum doesn't accept `strict:`: shy_enum attributes are strict, " \
                                 "unless you pass `validate:`"
          end
          return unless attribute_options.key?(:enum_class)

          raise ArgumentError, "shy_enum doesn't accept `enum_class:`: pass the enum as the second argument"
        end

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
