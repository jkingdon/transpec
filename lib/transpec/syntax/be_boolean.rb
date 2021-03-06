# coding: utf-8

require 'transpec/syntax'
require 'transpec/syntax/mixin/send'

module Transpec
  class Syntax
    class BeBoolean < Syntax
      include Mixin::Send

      def dynamic_analysis_target?
        super && receiver_node.nil? && [:be_true, :be_false].include?(method_name)
      end

      def be_true?
        method_name == :be_true
      end

      def convert_to_conditional_matcher!(form_of_be_falsey = 'be_falsey')
        replacement = be_true? ? 'be_truthy' : form_of_be_falsey
        replace(expression_range, replacement)
        register_record(replacement)
      end

      def convert_to_exact_matcher!
        replacement = be_true? ? 'be true' : 'be false'
        replace(expression_range, replacement)
        register_record(replacement)
      end

      private

      def register_record(converted_syntax)
        report.records << Record.new(method_name.to_s, converted_syntax)
      end
    end
  end
end
