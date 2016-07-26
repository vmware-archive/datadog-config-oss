require 'rspec'

describe Template do
  let(:template_file) { Tempfile.new('deleteme') }
  let(:search_and_replace) {
    {
      key:                     'value',
      diego_deployment:        'some-deployment-diego',
      deployment:              'some-deployment',
      metron_agent_deployment: {
        search:  'datadog\.nozzle.+\K(some-deployment)',
        replace: 'some-deployment'
      },
      bosh_deployment:         'some-bosh-deployment',
    }
  }

  subject(:template) { described_class.new(
    template_file:      template_file,
    search_and_replace: search_and_replace
  ) }

  after(:each) { FileUtils.rm(template_file) }

  it { is_expected.to be_a Template }

  describe '#new' do
    describe 'search_and_replace' do
      context 'can be a string' do
        let(:search_and_replace) {
          {
            deployment: 'some-deployment',
          }
        }

        describe '@search' do
          subject() { template.instance_variable_get(:@search) }
          it { is_expected.to match( { deployment: /some-deployment/ } ) }
        end
        describe '@replace' do
          subject() { template.instance_variable_get(:@replace) }
          it { is_expected.to match( { deployment: 'some-deployment' } ) }
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
          it { is_expected.to match( { metron_agent_deployment:  /datadog\.nozzle.+\K(some-deployment)/ } ) }
        end
        describe '@replace' do
          subject() { template.instance_variable_get(:@replace) }
          it { is_expected.to match( { metron_agent_deployment:  'some-deployment' } ) }
        end
      end
    end
  end


  describe '#to_datadog' do
    xit 'looks like json' do

    end

    describe '#to_string_from_erb' do
      it "convert values from erb vars" do
        expect(template.to_string("<%= deployment %>")).to eq("some-deployment")
        expect(template.to_string("<%= bosh_deployment %>")).to eq("some-bosh-deployment")
        expect(template.to_string("<%= deployment %> <%= diego_deployment %>")).to eq("some-deployment some-deployment-diego")
      end
    end

  end


  describe '#from_datadog' do
    it 'receives a json object from (purportedly datadog)' do

    end

    describe '#to_erb_from_string' do
      it "convert values back to erb vars" do
        expect(template.to_erb("some-deployment")).to eq("<%= deployment %>")
        expect(template.to_erb("some-bosh-deployment")).to eq("<%= bosh_deployment %>")
      end

      xit 'supports regex strings' do
        expect(template.to_erb("some-deployment")).to eq("<%= deployment %>")
        expect(template.to_erb("datadog.nozzle.asdf: { deployment: some-deployment }")).to
        eq("datadog.nozzle.asdf: { deployment: <%= metron_agent_deployment %> }")
      end

      it "can handle value overlaps though this is really a function of the order in which the keys appear" do
        expect(template.to_erb("some-deployment some-deployment-diego")).to eq(
                                                                              "<%= deployment %> <%= diego_deployment %>")
      end
    end

  end

end
