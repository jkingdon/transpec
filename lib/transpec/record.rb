# coding: utf-8

require 'transpec/annotatable'

module Transpec
  class Record
    OVERRIDE_FORBIDDEN_METHODS = [
      :original_syntax,
      :original_syntax_type,
      :converted_syntax,
      :converted_syntax_type
    ]

    attr_reader :original_syntax_type, :converted_syntax_type, :annotation

    def initialize(original_syntax, converted_syntax, annotation = nil)
      @original_syntax_type = original_syntax.to_sym
      @converted_syntax_type = converted_syntax.to_sym
      @annotation = annotation
    end

    def original_syntax
      original_syntax_type.to_s
    end

    def converted_syntax
      converted_syntax_type.to_s
    end

    def original_syntax_type
      @original_syntax_type ||= build_original_syntax.to_sym
    end

    def converted_syntax_type
      @converted_syntax_type ||= build_converted_syntax.to_sym
    end

    def ==(other)
      self.class == other.class &&
        original_syntax_type == other.original_syntax_type &&
        converted_syntax_type == other.converted_syntax_type
    end

    alias_method :eql?, :==

    def hash
      original_syntax_type.hash ^ converted_syntax_type.hash
    end

    def to_s
      "`#{original_syntax_type}` -> `#{converted_syntax_type}`"
    end

    private

    def build_original_syntax
      fail NotImplementedError
    end

    def build_converted_syntax
      fail NotImplementedError
    end

    def self.method_added(method_name)
      return unless OVERRIDE_FORBIDDEN_METHODS.include?(method_name)
      fail "Do not override Record##{method_name}."
    end
  end

  class Annotation
    include Annotatable
  end

  class AccuracyAnnotation < Annotation
    def initialize(source_range)
      message = "The `#{source_range.source}` has been converted " \
                'but it might possibly be incorrect ' \
                'due to a lack of runtime information. ' \
                "It's recommended to review the change carefully."
      super(message, source_range)
    end
  end
end
