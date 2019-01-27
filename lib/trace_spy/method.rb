module TraceSpy
  # Implements a TraceSpy on a Method
  #
  # @author baweaver
  # @since 0.0.1
  #
  # @note
  #   Tracer spies all rely on Qo for pattern-matching syntax. In order to more
  #   effectively leverage this gem it would be a good idea to look through
  #   the Qo documentation present here: https://github.com/baweaver/qo
  #
  # @example
  #   A simple use-case would be monitoring for a line in which c happens to be
  #   equal to 5. Now this value could be a range or other `===` respondant type
  #   if desired, which gives quite a bit of flexibility in querying.
  #
  #   ```ruby
  #   def testing(a, b)
  #     c = 5
  #
  #     a + b + c
  #   end
  #
  #   trace_spy = TraceSpy::Method.new(:testing) do |spy|
  #     spy.on_locals do |m|
  #       m.when(c: 5) { |locals| p locals }
  #     end
  #   end
  #
  #   trace_spy.enable
  #   # => false
  #
  #   testing(1, 2)
  #   # {:a=>1, :b=>2, :c=>5}
  #   # => 8
  #   ```
  class Method
    # The current trace being executed upon, can be used in matcher
    # blocks to get the entire trace context instead of just a part.
    attr_reader :current_trace

    # Creates a new method trace
    #
    # @param method_name [Symbol, String]
    #   Name of the method to watch, will be compared with `===` for flexibility
    #   which enables the use of regex and other more powerful matching
    #   techniques.
    #
    # @param from_class: Any [Any]
    #   Either a Class for type-matching, or other `===` respondant type for flexibility
    #
    # @param &fn [Proc]
    #   Self-yielding proc used to initialize a spy in one block function
    #
    # @yields self
    #
    # @return [TraceSpy::Method]
    def initialize(method_name, from_class: Any, &fn)
      @method_name   = method_name
      @from_class    = from_class
      @spies         = Hash.new { |h,k| h[k] = [] }
      @tracepoint    = nil
      @current_trace = nil

      yield(self) if block_given?
    end

    # Creates a Spy on function arguments
    #
    # @since 0.0.1
    #
    # @example
    #   Consider, you'd like to monitor if a particular argument is nil:
    #
    #   ```ruby
    #   def testing(a) a + 2 end
    #
    #   trace_spy = TraceSpy::Method.new(:testing) do |spy|
    #     spy.on_arguments do |m|
    #       m.when(a: nil) { |args| binding.pry }
    #     end
    #   end
    #   ```
    #
    #   You could use this to find out if there's a type-mismatch, or what
    #   the context is around a particular error due to an argument being
    #   a particular value.
    #
    # @param &matcher_fn [Proc]
    #   Qo Matcher
    #
    # @return [Array[Qo::Matcher]]
    #   Currently added Qo matchers
    def on_arguments(&matcher_fn)
      @spies[:arguments] << Qo.match(&matcher_fn)
    end

    # Creates a Spy on local method variables
    #
    # @since 0.0.2
    #
    # @example
    #   Consider, a local variable is inexplicably getting set equal to nil,
    #   and you don't know where it's happening:
    #
    #   ```ruby
    #   def testing(a)
    #     b = nil
    #     a + 2
    #   end
    #
    #   trace_spy = TraceSpy::Method.new(:testing) do |spy|
    #     spy.on_locals do |m|
    #       m.when(b: nil) { |args| binding.pry }
    #     end
    #   end
    #   ```
    #
    #   You can use this to stop your program precisely where the offending code
    #   is located without needing to know where it is beforehand.
    #
    # @param &matcher_fn [Proc]
    #   Qo Matcher
    #
    # @return [Array[Qo::Matcher]]
    #   Currently added Qo matchers
    def on_locals(&matcher_fn)
      @spies[:locals] << Qo.match(&matcher_fn)
    end

    # Creates a Spy on function returns
    #
    # @since 0.0.1
    #
    # @example
    #   Consider, you'd like to know when your logging method is returning
    #   an empty string:
    #
    #   ```ruby
    #   def logger(msg)
    #     rand(10) < 5 ? msg : ""
    #   end
    #
    #   trace_spy = TraceSpy::Method.new(:logger) do |spy|
    #     spy.on_return do |m|
    #       m.when("") { |v| binding.pry }
    #     end
    #   end
    #   ```
    #
    #   This could be used to find out the remaining context around what caused
    #   the blank message, like getting arguments from the `spy.current_trace`.
    #
    # @param &matcher_fn [Proc]
    #   Qo Matcher
    #
    # @return [Array[Qo::Matcher]]
    #   Currently added Qo matchers
    def on_return(&matcher_fn)
      @spies[:return] << Qo.match(&matcher_fn)
    end

    # Creates a Spy on a certain type of exception
    #
    # @since 0.0.1
    #
    # @example
    #   Consider, you'd like to find out where that error is coming from in
    #   your function:
    #
    #   ```ruby
    #   def testing(a)
    #     raise 'heck'
    #     a + 2
    #   end
    #
    #   trace_spy = TraceSpy::Method.new(:testing) do |spy|
    #     spy.on_exception do |m|
    #       m.when(RuntimeError) { |args| binding.pry }
    #     end
    #   end
    #   ```
    #
    #   Like return, you can use this to find out the context around why this
    #   particular error occurred.
    #
    # @param &matcher_fn [Proc]
    #   Qo Matcher
    #
    # @return [Array[Qo::Matcher]]
    #   Currently added Qo matchers
    def on_exception(&matcher_fn)
      @spies[:exception] << Qo.match(&matcher_fn)
    end

    # "Enables" the current tracepoint by defining it, caching it, and enabling it
    #
    # @since 0.0.1
    #
    # @return [FalseClass]
    #   Still not sure why TracePoint#enable returns `false`, but here we are
    def enable
      @tracepoint = TracePoint.new do |trace|
        begin
          next unless matches?(trace)

          @current_trace = trace

          call_with  = -> with { -> spy { spy.call(with) } }


          @spies[:arguments].each(&call_with[extract_args(trace)])    if CALL_EVENT.include?(trace.event)
          @spies[:locals].each(&call_with[extract_locals(trace)])     if LINE_EVENT.include?(trace.event)
          @spies[:return].each(&call_with[trace.return_value])        if RETURN_EVENT.include?(trace.event)
          @spies[:exception].each(&call_with[trace.raised_exception]) if RAISE_EVENT.include?(trace.event)

          @current_trace = nil
        rescue RuntimeError => e
          # Stupid hack for now
          p e
        end
      end

      @tracepoint.enable
    end

    # Disables the TracePoint, or pretends it did if one isn't enabled yet
    #
    # @since 0.0.1
    #
    # @return [Boolean]
    def disable
      !!@tracepoint&.disable
    end

    # Returns the local variables of the currently active trace
    #
    # @since 0.0.2
    #
    # @example
    #   This is a utility function for use with `spy` inside the matcher
    #   block.
    #
    #   ```ruby
    #   trace_spy = TraceSpy::Method.new(:testing) do |spy|
    #     spy.on_exception do |m|
    #       m.when(RuntimeError) do |v|
    #         p spy.current_local_variables
    #       end
    #     end
    #   end
    #   ```
    #
    #   It's meant to be used to expose the current local variables
    #   within a trace's scope in any type of matcher.
    #
    # @return [Hash[Symbol, Any]]
    def current_local_variables
      return {} unless @current_trace

      extract_locals(@current_trace)
    end

    # Returns the arguments of the currently active trace
    #
    # @since 0.0.2
    #
    # @note
    #   This method will attempt to avoid running in contexts where
    #   argument retrieval will give a runtime error.
    #
    # @example
    #   This is a utility function for use with `spy` inside the matcher
    #   block.
    #
    #   ```ruby
    #   trace_spy = TraceSpy::Method.new(:testing) do |spy|
    #     spy.on_return do |m|
    #       m.when(String) do |v|
    #         binding.pry if spy.current_arguments[:a] == 'foo'
    #       end
    #     end
    #   end
    #   ```
    #
    #   It's meant to expose the current arguments present in a trace's
    #   scope.
    #
    # @return [Hash[Symbol, Any]]
    def current_arguments
      return {} unless @current_trace
      return {} if RAISE_EVENT.include?(@current_trace.event)

      extract_args(@current_trace)
    end

    # Whether the current trace matches our current preconditions
    #
    # @since 0.0.1
    #
    # @param trace [Trace]
    #   Currently active Trace
    #
    # @return [Boolean]
    #   Whether or not the trace matches
    private def matches?(trace)
      method_matches?(trace) && class_matches?(trace)
    end

    # Whether the current trace fits the class constraints
    #
    # @since 0.0.1
    #
    # @param trace [Trace]
    #   Currently active Trace
    #
    # @return [Boolean]
    #   Whether or not the trace matches
    private def class_matches?(trace)
      return true if @from_class == Any

      @from_class == trace.defined_class || @from_class === trace.defined_class
    end

    # Whether the current trace fits the method constraints
    #
    # @since 0.0.1
    #
    # @param trace [Trace]
    #   Currently active Trace
    #
    # @return [Boolean]
    #   Whether or not the trace matches
    private def method_matches?(trace)
      @method_name === trace.method_id
    end

    # Extracts the arguments from a given trace
    #
    # @since 0.0.1
    #
    # @param trace [Trace]
    #
    # @return [Hash[Symbol, Any]]
    #   Hash mapping argument names to their respective values
    private def extract_args(trace)
      param_names = trace.parameters.map(&:last)

      param_names.map { |n| [n, trace.binding.eval(n.to_s)] }.to_h
    end

    # Extracts the local variables from a given trace
    #
    # @since 0.0.1
    #
    # @param trace [Trace]
    #
    # @return [Hash[Symbol, Any]]
    #   Hash mapping local variable names to their respective values
    private def extract_locals(trace)
      local_names = trace.binding.eval('local_variables')
      local_names.map { |n| [n, trace.binding.eval(n.to_s)] }.to_h
    end
  end
end
