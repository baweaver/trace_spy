RSpec.describe TraceSpy::Method do
  def standard_method(a, b, c)
    a + b + c
  end

  def local_method(a, b, c)
    d = 10

    a + b + c + d
  end

  def exception_method(a)
    raise 'heck' unless a > 5

    a + 5
  end

  let(:method_name) { :standard_method }
  let(:klass) { Any }
  let(:spy_function) { proc {} }

  let(:target) { double('target') }

  let(:subject) {
    TraceSpy::Method.new(method_name, from_class: klass, &spy_function)
  }

  describe '.initialize' do
    it 'creates a new Method spy' do
      expect(subject).to be_a(TraceSpy::Method)
    end
  end

  describe 'Argument Spies' do
    let(:spy_function) {
      -> spy {
        spy.on_arguments do |m|
          m.when(a: 5) { |args| target.call(args) }
        end
      }
    }

    it 'can spy on an arguments value' do
      subject.with_tracing do
        expect(target).to receive(:call).with(
          a: 5,
          b: 2,
          c: 3
        )

        expect(standard_method(5, 2, 3)).to eq(10)
      end
    end

    it 'will not be called if the argument predicate is not matched' do
      subject.with_tracing do
        expect(target).not_to receive(:call)

        expect(standard_method(1, 2, 3)).to eq(6)
      end
    end
  end

  describe 'Local Spies' do
    let(:method_name) { :local_method }

    let(:spy_function) {
      -> spy {
        spy.on_locals do |m|
          m.when(d: 10) { |locals| target.call(locals) }
        end
      }
    }

    it 'can spy on an arguments value' do
      subject.with_tracing do
        expect(target).to receive(:call).with(
          a: 5,
          b: 2,
          c: 3,
          d: 10
        )

        local_method(5, 2, 3)
      end
    end

    context 'When the local variable is not defined' do
      let(:method_name) { :standard_method }

      it 'will not be called if the argument predicate is not matched' do
        subject.with_tracing do
          expect(target).not_to receive(:call)

          standard_method(1, 2, 3)
        end
      end
    end
  end

  describe 'Return Spies' do
    let(:spy_function) {
      -> spy {
        spy.on_return do |m|
          m.when(:even?) { |return_value| target.call(return_value) }
        end
      }
    }

    it 'can spy on an arguments value' do
      subject.with_tracing do
        expect(target).to receive(:call).with(6)
        expect(standard_method(1, 2, 3)).to eq(6)
      end
    end

    it 'will not be called if the return predicate is not matched' do
      subject.with_tracing do
        expect(target).not_to receive(:call)
        expect(standard_method(2, 2, 3)).to eq(7)
      end
    end
  end

  describe 'Exception Spies' do
    let(:method_name) { :exception_method }

    let(:spy_function) {
      -> spy {
        spy.on_exception do |m|
          m.when(RuntimeError) { |e| target.call(e) }
        end
      }
    }

    it 'can spy on an arguments value' do
      subject.with_tracing do
        expect(target).to receive(:call).with(instance_of(RuntimeError))
        expect { exception_method(1) }.to raise_error(RuntimeError, 'heck')
      end
    end

    it 'will not be called if the return predicate is not matched' do
      subject.with_tracing do
        expect(target).not_to receive(:call)
        expect(exception_method(6)).to eq(11)
      end
    end
  end

  describe '#current_local_variables' do
    let(:method_name) { :local_method }

    let(:spy_function) {
      -> spy {
        spy.on_return do |m|
          m.when(:even?) { |_| target.call(spy.current_local_variables) }
        end
      }
    }

    it 'can reference the current local variables without needing on_locals' do
      subject.with_tracing do
        expect(target).to receive(:call).with(
          a: 2,
          b: 2,
          c: 2,
          d: 10
        )

        local_method(2, 2, 2)
      end
    end
  end

  describe '#current_arguments' do
    let(:method_name) { :local_method }

    let(:spy_function) {
      -> spy {
        spy.on_return do |m|
          m.when(:even?) { |_| target.call(spy.current_arguments) }
        end
      }
    }

    it 'can reference the current arguments without needing on_arguments' do
      subject.with_tracing do
        expect(target).to receive(:call).with(
          a: 2,
          b: 2,
          c: 2
        )

        local_method(2, 2, 2)
      end
    end
  end
end
