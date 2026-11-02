# frozen_string_literal: true

require_relative "test_helper"

module Shy
  class ShyEnumTest < Minitest::Test
    # With `validate: true`, as in Rails' `enum`, assigning a value that is not a
    # member doesn't raise: the inclusion validation checks it. Unlike Rails, nil
    # is valid.
    class LoosePost < ApplicationRecord
      self.table_name = "posts"

      shy_enum :status, Status, validate: true, suffix: :state
    end

    class RawPost < ApplicationRecord
      self.table_name = "posts"

      attribute :status, :shy_enum, enum_class: Status
    end

    # Generated methods can be overridden calling super
    class OverridingPost < ApplicationRecord
      self.table_name = "posts"

      shy_enum :status, Status

      def draft!
        @override_worked = true
        super
      end
    end

    class State < Shy::Enum::Base
      Open = new
      Closed = new

      freeze
    end

    class Output < Shy::Enum::Base
      Format = new
      Test = new

      freeze
    end

    class Visibility < Shy::Enum::Base
      Public = new
      Hidden = new

      freeze
    end

    class Protocol < Shy::Enum::Base
      HTTP = new
      Http = new("h2")

      freeze
    end

    class Other < Shy::Enum::Base
      Published = new

      freeze
    end

    def setup
      Post.delete_all
    end

    class Persistence < ShyEnumTest
      def test_persist_and_reload
        post = Post.create!(status: Status::InProgress, priority: Priority::High)
        post.reload

        assert_equal Status::InProgress, post.status
        assert_equal Priority::High, post.priority
        assert_equal "inprogress", raw_value("SELECT status FROM posts")
        assert_equal 1, raw_value("SELECT priority FROM posts")
      end

      def test_default
        assert_equal Status::Draft, Post.new.status
      end

      def test_where
        a = Post.create!(status: "draft")
        b = Post.create!(status: "published")

        assert_equal [a], Post.where(status: Status::Draft).to_a
        assert_equal [b], Post.where(status: "published").to_a
        assert_equal [a, b].sort_by(&:id), Post.where(status: [Status::Draft, "published"]).order(:id).to_a
      end

      # Querying with a member of another enum raises a clear error
      def test_where_with_member_of_other_enum
        error = assert_raises(Shy::Enum::Error) { Post.where(status: Other::Published).to_a }

        assert_equal <<~MESSAGE.chomp, error.message
          Can't serialize #<Shy::ShyEnumTest::Other::Published value="published">: it is not a member of Status
        MESSAGE
      end

      # A blank string is stored as NULL and read back as nil
      def test_blank_string_stored_as_nil
        post = Post.create!(status: "")

        assert_nil raw_value("SELECT status FROM posts WHERE id = #{post.id}")
        assert_nil Post.find(post.id).status
      end

      def test_attribute_without_macro
        post = RawPost.create!(status: Status::Published)

        assert_equal Status::Published, RawPost.find(post.id).status
      end

      def test_dirty_tracking
        post = Post.create!

        refute_predicate post, :status_changed?
        post.status = "published"

        assert_predicate post, :status_changed?
        post.save!

        refute_predicate post, :status_changed?
      end

      # Changes hold members, where Rails' enum holds labels
      def test_changes_hold_members
        post = Post.create!
        post.status = "published"

        assert_equal({ "status" => [Status::Draft, Status::Published] }, post.changes)
      end
    end

    class GeneratedMethods < ShyEnumTest
      def test_scopes
        a = Post.create!(status: "draft")
        b = Post.create!(status: "inprogress")

        assert_equal [a], Post.draft.to_a
        assert_equal [b], Post.not_draft.to_a
        assert_equal [b], Post.in_progress.to_a
      end

      def test_predicates_and_bang
        post = Post.create!

        assert_predicate post, :draft?
        refute_predicate post, :published?
        post.published!

        assert_predicate post.reload, :published?
      end

      def test_class_reader
        expected = { "draft" => Status::Draft, "in_progress" => Status::InProgress, "published" => Status::Published }

        assert_equal expected, Post.statuses
        assert_predicate Post.statuses, :frozen?
      end

      def test_class_reader_has_indifferent_access
        assert_equal Status::InProgress, Post.statuses[:in_progress]
        assert_equal Status::InProgress, Post.statuses["in_progress"]
      end

      # Like Rails' enum, the keys don't have the prefix
      def test_class_reader_ignores_prefix
        assert_equal %w[low high], Post.priorities.keys
      end

      def test_prefix_suffix
        assert_respond_to Post.new, :priority_low?
        refute_respond_to Post.new, :low?
        assert_respond_to LoosePost.new, :draft_state?
        assert_respond_to LoosePost.new, :in_progress_state!
        assert_respond_to LoosePost, :draft_state
        refute_respond_to Post, :priority_low
      end

      def test_override_generated_methods_with_super
        post = OverridingPost.create!(status: Status::Published)
        post.draft!

        assert post.instance_variable_get(:@override_worked)
        assert_predicate post.reload, :draft?, "super saves the record"
      end

      def test_generated_methods_module_name
        mod = Post.ancestors[1]

        assert_equal "Shy::ShyEnumTest::OverridingPost::ShyEnumMethods(anonymous)",
                     OverridingPost.ancestors[1].name
        assert_equal "Post::ShyEnumMethods(anonymous)", mod.name
        assert_includes mod.instance_methods(false), :draft?
      end
    end

    class Conflicts < ShyEnumTest
      def test_conflicts
        assert_raises(Shy::Enum::Error) { conflicting { define_method(:draft?) { false } } }
        assert_raises(Shy::Enum::Error) { conflicting { define_singleton_method(:draft) { nil } } }
      end

      # Labels named like private Kernel/Object methods are allowed
      def test_labels_named_like_private_object_methods
        states = with_enum(:status, State)
        outputs = with_enum(:status, Output)
        open = states.create!(status: State::Open)
        test = outputs.create!(status: Output::Test)

        assert_equal [open], states.open.to_a
        assert_predicate open, :open?
        assert_equal [test], outputs.test.to_a
        assert_empty outputs.format.to_a
      end

      # Labels restricted by Rails, or shadowing a Kernel method
      # redefined in the model, are still conflicts
      def test_labels_restricted_or_redefined_are_conflicts
        assert_raises(Shy::Enum::Error) { with_enum(:status, Visibility) }
        assert_raises(Shy::Enum::Error) { conflicting(State) { define_singleton_method(:open) { nil } } }
      end

      # Two members with the same label are a conflict
      def test_duplicate_labels_raise
        error = assert_raises(Shy::Enum::Error) { with_enum(:status, Protocol) }

        assert_equal <<~MESSAGE.chomp, error.message
          Can't define `http`: members HTTP and Http have the same label
        MESSAGE
      end

      def test_duplicate_labels_raise_without_methods_and_scopes
        assert_raises(Shy::Enum::Error) do
          Class.new(ApplicationRecord) do
            self.table_name = "posts"
            shy_enum :status, Protocol, scopes: false, instance_methods: false
          end
        end
      end
    end

    class StrictAndValidation < ShyEnumTest
      def test_strict_by_default
        assert_raises(ArgumentError) { Post.new(status: "nope") }
      end

      def test_strict_option_rejected
        error = assert_raises(ArgumentError) { with_enum(:status, Status, strict: false) }

        assert_equal <<~MESSAGE.chomp, error.message
          shy_enum doesn't accept `strict:`: shy_enum attributes are strict, unless you pass `validate:`
        MESSAGE
      end

      def test_enum_class_option_rejected
        error = assert_raises(ArgumentError) { with_enum(:status, Status, enum_class: Status) }

        assert_equal <<~MESSAGE.chomp, error.message
          shy_enum doesn't accept `enum_class:`: pass the enum as the second argument
        MESSAGE
      end

      def test_validate
        post = LoosePost.new(status: "nope")

        refute_predicate post, :valid?
        assert post.errors.of_kind?(:status, :inclusion)
        assert_predicate LoosePost.new(status: nil), :valid?
        assert_predicate LoosePost.new(status: "draft"), :valid?
      end

      # With validate:, a blank string is nil, so it is valid
      def test_validate_blank_string_is_nil
        post = LoosePost.new(status: "")

        assert_predicate post, :valid?
        assert_nil post.status
      end
    end

    class UnknownStoredValues < ShyEnumTest
      def test_unaligned_value_raises_on_read
        post = Post.create!
        post.update_columns(status: "bogus")
        post = Post.find(post.id)

        assert_raises(Shy::Enum::Error) { post.status }
      end

      # An unknown stored value breaks only the reader
      def test_unaligned_value_does_not_break_inspect_and_attributes
        post = Post.create!
        post.update_columns(status: "bogus")
        post = Post.find(post.id)

        assert_match(/bogus/, post.inspect)
        assert_equal "bogus", post.attributes["status"]
        assert_raises(Shy::Enum::Error) { post.status }
      end
    end

    private

    # The value stored in the database, skipping the type
    def raw_value(sql) = Post.with_connection { it.select_value(sql) }

    def conflicting(enum_class = Status, &)
      Class.new(ApplicationRecord) do
        self.table_name = "posts"
        class_eval(&)
        shy_enum :status, enum_class
      end
    end

    def with_enum(name, enum_class, **)
      Class.new(ApplicationRecord) do
        self.table_name = "posts"
        def self.name = "AnonymousPost"
        shy_enum(name, enum_class, **)
      end
    end
  end
end
