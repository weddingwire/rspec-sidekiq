require 'spec_helper'

RSpec.describe RSpec::Sidekiq::Matchers::HaveEnqueuedJob do
  let(:tomorrow) { DateTime.now + 1 }
  let(:interval) { 3.minutes }
  let(:argument_subject) { RSpec::Sidekiq::Matchers::HaveEnqueuedJob.new worker_args }
  let(:matcher_subject) { RSpec::Sidekiq::Matchers::HaveEnqueuedJob.new [be_a(String), be_a(Fixnum), true, be_a(Hash)] }
  let(:worker) { create_worker }
  let(:worker_args) { ['string', 1, true, {key: 'value', bar: :foo, nested: [{hash: true}]}] }
  let(:active_job) { create_active_job :mailers }
  let(:resource) { TestResource.new }

  before(:each) do
    worker.perform_async *worker_args
    active_job.perform_later 'someResource'
    active_job.perform_later(resource)
    TestActionMailer.testmail.deliver_later
    TestActionMailer.testmail(resource).deliver_later
    argument_subject.matches? worker
  end

  describe 'expected usage' do
    it 'matches' do
      expect(worker).to have_enqueued_job *worker_args
    end

    it 'matches on the global Worker queue' do
      expect(Sidekiq::Worker).to have_enqueued_job *worker_args
    end

    it 'matches on an enqueued ActiveJob' do
      expect(Sidekiq::Worker).to have_enqueued_job 'someResource'
    end

    it 'matches on an enqueued ActiveJob by global_id' do
      expect(Sidekiq::Worker).to have_enqueued_job("_aj_globalid" => resource.to_global_id.uri.to_s)
    end

    it 'matches on ActionMailer Job' do
      expect(Sidekiq::Worker).to have_enqueued_job(
        "TestActionMailer",
        "testmail",
        "deliver_now"
      )
    end

    it 'matches on ActionMailer with a resource Job' do
      expect(Sidekiq::Worker).to have_enqueued_job(
        "TestActionMailer",
        "testmail",
        "deliver_now",
        { "_aj_globalid" => resource.to_global_id.uri.to_s }
      )
    end

    context "perform_in" do
      let(:worker_args_in) { worker_args + ['in'] }

      before(:each) do
        worker.perform_in 3.minutes, *worker_args_in
      end

      it 'matches on an scheduled job with #perform_in' do
        expect(worker).to have_enqueued_job(*worker_args_in).in(interval)
      end
    end

    context "perform_at" do
      let(:worker_args_at) { worker_args + ['at'] }

      before(:each) do
        worker.perform_at tomorrow, *worker_args_at
      end

      it 'matches on an scheduled job with #perform_at' do
        expect(worker).to have_enqueued_job(*worker_args_at).at(tomorrow)
      end
    end
  end

  describe '#have_enqueued_job' do
    it 'returns instance' do
      expect(have_enqueued_job).to be_a RSpec::Sidekiq::Matchers::HaveEnqueuedJob
    end
  end

  describe '#description' do
    it 'returns description' do
      expect(argument_subject.description).to eq "have an enqueued #{worker} job with arguments [\"string\", 1, true, {\"key\"=>\"value\", \"bar\"=>\"foo\", \"nested\"=>[{\"hash\"=>true}]}]"
    end
  end

  describe '#failure_message' do
    it 'returns message' do
      expect(argument_subject.failure_message).to eq "expected to have an enqueued #{worker} job with arguments [\"string\", 1, true, {\"key\"=>\"value\", \"bar\"=>\"foo\", \"nested\"=>[{\"hash\"=>true}]}]\n\nfound: [[\"string\", 1, true, {\"key\"=>\"value\", \"bar\"=>\"foo\", \"nested\"=>[{\"hash\"=>true}]}]]"
    end
  end

  describe '#matches?' do
    context 'when condition matches' do
      context 'when expected are arguments' do
        it 'returns true' do
          expect(argument_subject.matches? worker).to be true
        end
      end

      context 'when expected are matchers' do
        it 'returns true' do
          expect(matcher_subject.matches? worker).to be true
        end
      end

      context 'when job is scheduled' do
        context 'with #perform_at' do
          before(:each) do
            worker.perform_at(tomorrow)
          end

          it 'returns true' do
            expect(matcher_subject.at(tomorrow).matches? worker).to be true
          end
        end

        context 'with #perform_in' do
          before(:each) do
            worker.perform_in(interval)
          end

          it 'returns true' do
            expect(matcher_subject.in(interval).matches? worker).to be true
          end
        end
      end
    end

    context 'when condition does not match' do
      before(:each) { Sidekiq::Worker.clear_all }

      context 'when expected are arguments' do
        it 'returns false' do
          expect(argument_subject.matches? worker).to be false
        end
      end

      context 'when expected are matchers' do
        it 'returns false' do
          expect(matcher_subject.matches? worker).to be false
        end
      end

      context 'when job is scheduled' do
        before(:each) do
          allow(matcher_subject).to receive(:options).and_return(at: tomorrow)
        end

        it 'returns true' do
          expect(matcher_subject.at(tomorrow).matches? worker).to be false
        end
      end
    end
  end

  describe '#failure_message_when_negated' do
    it 'returns message' do
      expect(argument_subject.failure_message_when_negated).to eq "expected to not have an enqueued #{worker} job with arguments [\"string\", 1, true, {\"key\"=>\"value\", \"bar\"=>\"foo\", \"nested\"=>[{\"hash\"=>true}]}]"
    end
  end
end
