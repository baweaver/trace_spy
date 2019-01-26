module TraceSpy
  class Method
    def initialize(method_name, &fn)
      @method_name = method_name
      @spies       = Hash.new { |h,k| h[k] = [] }
      @tracepoint  = nil

      yield(self) if block_given?
    end

    def on_arguments(&matcher_fn)
      @spies[:arguments] << Qo.match(&matcher_fn)
    end

    def on_return(&matcher_fn)
      @spies[:return] << Qo.match(&matcher_fn)
    end

    def on_exception(&matcher_fn)
      @spies[:exception] << Qo.match(&matcher_fn)
    end

    def enable
      @tracepoint = TracePoint.new do |trace|
        begin
          next unless trace.method_id == @method_name

          call_with  = -> with { -> spy { spy.call(with) } }

          @spies[:arguments].each(&call_with[extract_args(trace)])    if CALL_EVENT.include?(trace.event)
          @spies[:return].each(&call_with[trace.return_value])        if RETURN_EVENT.include?(trace.event)
          @spies[:exception].each(&call_with[trace.raised_exception]) if RAISE_EVENT.include?(trace.event)
        rescue RuntimeError => e
          # Stupid hack for now
          p e
        end
      end

      @tracepoint.enable
    end

    def disable
      @tracepoint&.disable
    end

    def extract_args(trace)
      param_names = trace.parameters.map(&:last)

      param_names.map { |n| [n, trace.binding.eval(n.to_s)] }.to_h
    end
  end
end
