# frozen_string_literal: true

require_relative "enum/version"
require_relative "enum/has_enum"

module Shy
  module Enum
    class Error < StandardError
    end

    class Base # rubocop:disable Style/Documentation
      def self.registry
        @registry ||= Set.new
      end

      def self.t(constant_as_symbol)
        enum_type = new(constant_as_symbol)
        registry << enum_type
      end

      def self.close!
        freeze
      end

      attr_reader :ord, :name, :value

      def initialize(name)
        raise(Error, "Can't add new values to a closed Enum") if self.class.frozen?

        @name = name
        @value = name.to_s.downcase
        @ord = self.class.registry.size.next
        freeze
        self.class.const_set name, self
      end
      private_class_method :new

      def <=>(other)
        ord <=> other.ord
      end
      include Comparable
    end
  end
end
