require 'spec_helper'

module Events
  class TestEvent; end

  class AnotherTestEvent; end

  module MalformedTestEvent; end
end

class MyHandler
  def call(*); end
end

class MyMalformedHandler; end

describe Aruba::EventBus do
  subject(:bus) { described_class.new(name_resolver) }

  let(:name_resolver) { instance_double('Events::NameResolver') }

  let(:event_klass) { Events::TestEvent }
  let(:event_name) { event_klass }
  let(:event_instance) { Events::TestEvent.new }

  let(:another_event_klass) { Events::AnotherTestEvent }
  let(:another_event_name) { another_event_klass }
  let(:another_event_instance) { Events::AnotherTestEvent.new }

  describe '#notify' do
    before do
      allow(name_resolver)
        .to receive(:transform).with(event_name).and_return(event_klass)
    end

    context 'when subscribed to the event' do
      before do
        bus.register(event_klass) do |event|
          @received_payload = event
        end

        bus.notify event_instance
      end

      it 'calls the block with an instance of the event passed as payload' do
        expect(@received_payload).to eq(event_instance)
      end
    end

    context 'when not subscriber to event' do
      before do
        @received_payload = false
        bus.register(event_klass) { @received_payload = true }
        bus.notify another_event_instance
      end

      it { expect(@received_payload).to eq(false) }
    end

    context 'when event is not an instance of event class' do
      let(:event_name) { :test_event }
      let(:received_payload) { [] }

      before do
        bus.register(event_name, proc { nil })
      end

      it { expect { bus.notify event_klass }.to raise_error Aruba::NoEventError }
    end
  end

  describe '#register' do
    before do
      allow(name_resolver)
        .to receive(:transform).with(event_name).and_return(event_klass)
    end

    context 'when valid subscriber' do
      context 'when multiple instances are given' do
        let(:received_events) { [] }

        before do
          bus.register(Events::TestEvent) do |event|
            received_events << event
          end
          bus.register(Events::TestEvent) do |event|
            received_events << event
          end

          bus.notify event_instance
        end

        it { expect(received_events.length).to eq 2 }
        it { expect(received_events).to all eq event_instance }
      end

      context 'when is string' do
        let(:event_name) { event_klass.to_s }
        let(:received_payload) { [] }

        before do
          bus.register(event_klass.to_s) do |event|
            received_payload << event
          end

          bus.notify event_instance
        end

        it { expect(received_payload).to include event_instance }
      end

      context 'when is symbol and event is defined in the default namespace' do
        let(:event_name) { :test_event }
        let(:received_payload) { [] }

        before do
          bus.register(event_name) do |event|
            received_payload << event
          end

          bus.notify event_instance
        end

        it { expect(received_payload).to include event_instance }
      end
    end

    context 'when valid custom handler' do
      context 'when single event class' do
        before do
          allow(name_resolver)
            .to receive(:transform).with(event_name).and_return(event_klass)
          bus.register(event_klass, MyHandler.new)
        end

        it { expect { bus.notify event_instance }.not_to raise_error }
      end

      context 'when list of event classes' do
        before do
          allow(name_resolver)
            .to receive(:transform).with(event_name).and_return(event_klass)
          allow(name_resolver)
            .to receive(:transform).with(another_event_name).and_return(another_event_klass)
          bus.register([event_klass, another_event_klass], MyHandler.new)
        end

        it { expect { bus.notify event_instance }.not_to raise_error }
        it { expect { bus.notify another_event_instance }.not_to raise_error }
      end
    end

    context 'when malformed custom handler' do
      it 'raises an ArgumentError' do
        expect { bus.register(event_klass, MyMalformedHandler.new) }
          .to raise_error ArgumentError
      end
    end

    context 'when no handler is given' do
      it 'raises an ArgumentError' do
        expect { bus.register(event_klass) }.to raise_error ArgumentError
      end
    end
  end
end
