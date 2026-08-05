# frozen_string_literal: true

require_relative 'base_builder'

module EasyTalk
  module Builders
    # Builder class for number properties.
    class NumberBuilder < BaseBuilder
      VALID_OPTIONS = {
        multiple_of: { type: T.any(Integer, Float, BigDecimal), key: :multipleOf },
        minimum: { type: T.any(Integer, Float, BigDecimal), key: :minimum },
        maximum: { type: T.any(Integer, Float, BigDecimal), key: :maximum },
        exclusive_minimum: { type: T.any(Integer, Float, BigDecimal), key: :exclusiveMinimum },
        exclusive_maximum: { type: T.any(Integer, Float, BigDecimal), key: :exclusiveMaximum },
        enum: { type: T::Array[T.any(Integer, Float, BigDecimal)], key: :enum },
        const: { type: T.any(Integer, Float, BigDecimal), key: :const },
        default: { type: T.any(Integer, Float, BigDecimal), key: :default }
      }.freeze

      # Initializes a new instance of the NumberBuilder class.
      sig { params(name: Symbol, constraints: Hash).void }
      def initialize(name, constraints = {})
        super(name, { type: 'number' }, constraints, VALID_OPTIONS)
      end
    end
  end
end
