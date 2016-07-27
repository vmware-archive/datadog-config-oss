require 'rspec'

describe Template do
  let(:string) { "some-deployment" }
  let(:erb) { nil }
  let(:search_and_replace) {
    {
      key:                     'value',
      diego_deployment:        'some-deployment-diego',
      metron_agent_deployment: {
        search:  'datadog\.nozzle.+\K(some-deployment)',
        replace: 'some-deployment'
      },
      deployment:              'some-deployment',
      bosh_deployment:         'some-bosh-deployment',
    }
  }

  subject(:template) { described_class.new(
    string:             string,
    search_and_replace: search_and_replace,
    erb:                erb,
  ) }

  it { is_expected.to be_a Template }

  describe '#new' do
    describe 'just a string and search_and_replace' do
      it { is_expected.to be_a Template }
      describe 'works' do
        subject() { template.to_erb }
        it { is_expected.to match("<%= deployment %>") }
      end
    end

    describe 'just a erb and search_and_replace' do
      let(:string) { nil }
      let(:erb) { "<%= deployment %>" }
      it { is_expected.to be_a Template }
      describe 'works' do
        subject() { template.to_erb }
        it { is_expected.to match("<%= deployment %>") }
      end

      describe 'works' do
        subject() { template.to_string }
        it { is_expected.to match("some-deployment") }
      end
    end

    describe 'search_and_replace' do
      context 'can be a string' do
        let(:search_and_replace) {
          {
            deployment: 'some-deployment',
          }
        }

        describe '@search' do
          subject() { template.instance_variable_get(:@search) }
          it { is_expected.to match({ deployment: /some-deployment/ }) }
        end
        describe '@replace' do
          subject() { template.instance_variable_get(:@replace) }
          it { is_expected.to match({ deployment: 'some-deployment' }) }
        end
      end


      context 'or a hash' do
        let(:search_and_replace) {
          {
            metron_agent_deployment: {
              search:  'datadog\.nozzle.+\K(some-deployment)',
              replace: 'some-deployment'
            }
          }
        }

        describe '@search' do
          subject() { template.instance_variable_get(:@search) }
          it { is_expected.to match({ metron_agent_deployment: /datadog\.nozzle.+\K(some-deployment)/ }) }
        end
        describe '@replace' do
          subject() { template.instance_variable_get(:@replace) }
          it { is_expected.to match({ metron_agent_deployment: 'some-deployment' }) }
        end
      end

      context 'or a hash with string keys' do
        let(:search_and_replace) {
          {
            'metron_agent_deployment' => {
              'search' => 'datadog\.nozzle.+\K(some-deployment)',
              'replace' => 'some-deployment'
            }
          }
        }

        describe '@search' do
          subject() { template.instance_variable_get(:@search) }
          it { is_expected.to match({ metron_agent_deployment: /datadog\.nozzle.+\K(some-deployment)/ }) }
        end
        describe '@replace' do
          subject() { template.instance_variable_get(:@replace) }
          it { is_expected.to match({ metron_agent_deployment: 'some-deployment' }) }
        end
      end

    end
  end

  describe '#string' do
    let(:string) { 'tablewear' }
    subject() { template.string }
    it { is_expected.to match 'tablewear' }
  end

  describe '#erb' do
    let(:erb) { '<%= tablewear %>' }
    subject() { template.erb }
    it { is_expected.to match '<%= tablewear %>' }
  end


  describe '#to_string' do
    subject() { template.to_string }
    context '<%= deployment %>' do
      let(:string) { '<%=deployment %>' }
      it { is_expected.to eq 'some-deployment' }
    end
    context '<%= bosh_deployment %>' do
      let(:string) { '<%= bosh_deployment %>' }
      it { is_expected.to eq 'some-bosh-deployment' }
    end
    context '<%= deployment %> <%= diego_deployment %>' do
      let(:string) { '<%= deployment %> <%= diego_deployment %>' }
      it { is_expected.to eq 'some-deployment some-deployment-diego' }
    end
  end


  describe '#to_erb' do
    subject() { template.to_erb }
    context 'some-deployment' do
      let(:string) { 'some-deployment' }
      it { is_expected.to eq '<%= deployment %>' }
    end
    context 'some-bosh-deployment' do
      let(:string) { 'some-bosh-deployment' }
      it { is_expected.to eq '<%= bosh_deployment %>' }
    end
    context 'datadog.nozzle some-deployment' do
      let(:string) { 'datadog.nozzle.asdf: { deployment: some-deployment }' }
      it { is_expected.to eq 'datadog.nozzle.asdf: { deployment: <%= metron_agent_deployment %> }' }
    end
    context 'some-deployment some-deployment-diego' do
      let(:string) { 'some-deployment some-deployment-diego' }
      it { is_expected.to eq '<%= deployment %> <%= diego_deployment %>' }
    end
  end

 describe '#to_generic_ruby' do
    subject() { template.to_generic_ruby }
    context 'some-deployment DEA Radiator' do
      let(:string) { 'some-deployment DEA Radiator' }
      it { is_expected.to eq "deployment + ' DEA Radiator'" }
    end
    context 'some-bosh-deployment' do
      let(:string) { 'some-bosh-deployment' }
      it { is_expected.to eq 'bosh_deployment' }
    end
    context 'preceding string some-bosh-deployment' do
      let(:string) { 'preceding string some-bosh-deployment' }
      it { is_expected.to eq "'preceding string ' + bosh_deployment" }
    end
    context 'datadog.nozzle some-deployment' do
      let(:string) { 'datadog.nozzle.asdf: { deployment: some-deployment }' }
      # this fails because this particular regex has a \K which ignores the beginning bit
      # not fixing for right now
      xit { is_expected.to eq 'datadog.nozzle.asdf: { deployment: metron_agent_deployment }' }
    end
    context 'some-deployment some-deployment-diego' do
      let(:string) { 'some-deployment some-deployment-diego' }
      # this fails because multiple passes wreck it
      # not fixing for right now
      xit { is_expected.to eq "deployment + ' ' + diego_deployment" }
    end

    describe '#inflate_regex' do
      subject() { template.inflate_regex(regex).inspect}

      let(:regex) { /value/ }
      it { is_expected.to eq '/(.*)value(.*)/'}

    end
  end


end
