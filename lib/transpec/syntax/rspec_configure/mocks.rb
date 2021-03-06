# coding: utf-8

require 'transpec/syntax/rspec_configure/framework'

module Transpec
  class Syntax
    class RSpecConfigure
      class Mocks < Framework
        def block_method_name
          :mock_with
        end

        def yield_receiver_to_any_instance_implementation_blocks=(boolean)
          set_config!(:yield_receiver_to_any_instance_implementation_blocks, boolean)
        end
      end
    end
  end
end
