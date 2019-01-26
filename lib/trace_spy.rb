require "trace_spy/version"

require 'qo'

module TraceSpy
  class Error < StandardError; end

  CALL_EVENT   = Set.new([:call, :c_call])
  RETURN_EVENT = Set.new([:return, :c_return])
  RAISE_EVENT  = Set.new([:raise])
end

require 'trace_spy/method'
