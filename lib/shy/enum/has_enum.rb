# frozen_string_literal: true

module Shy
  module Enum
    module HasEnum # rubocop:disable Style/Documentation
      def enum(klass) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        ivar_name = :"@#{klass.name.downcase}_enum"

        define_method(klass.name.downcase) do
          instance_variable_get(ivar_name)
        end

        define_method("#{klass.name.downcase}=") do |type_to_set|
          raise(Error, "Type error. Enum type must be of the same class") unless type_to_set.is_a?(klass)

          instance_variable_set(ivar_name, type_to_set)
        end

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
