require "trace_spy/version"

require 'qo'

# A Wrapper around TracePoint to provide a more flexible API
#
# @author baweaver
# @since 0.0.1
#
module TraceSpy
  # Method call events
  CALL_EVENT   = Set.new([:call, :c_call])

  # Method return events
  RETURN_EVENT = Set.new([:return, :c_return])

  # Exception events
  RAISE_EVENT  = Set.new([:raise])

  # Line execution events
  LINE_EVENT  = Set.new([:line])

  # TODO: Implement other event types
end

require 'trace_spy/method'
