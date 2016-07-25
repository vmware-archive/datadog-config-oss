require 'rspec'

describe Template do
  let(:template_file)  {Tempfile.new('deleteme')}
  let(:search_and_replace) {
    {
      key: 'value',
      diego_deployment: 'some-deployment-diego',
      deployment: 'some-deployment',
      bosh_deployment: 'some-bosh-deployment',
    }
  }

  subject(:template) {described_class.new(
    template_file: template_file,
    search_and_replace: search_and_replace
  )}

  after(:each) { FileUtils.rm(template_file)}

  it { is_expected.to be_a Template }

  describe '#new' do
    describe 'instance_variables' do
      describe '@template_file' do
        subject() { template.instance_variable_get(:@template_file) }
        it { is_expected.to match template_file }
      end

      describe '@search_and_replace' do
        subject() { template.instance_variable_get(:@search_and_replace) }
        it { is_expected.to match search_and_replace }
      end

    end
  end

  describe '#raw' do

  end


  describe '#to_datadog' do
    xit 'looks like json' do

    end

    describe '#to_string_from_erb' do
      it "convert values from erb vars" do
        expect(template.to_string_from_erb("<%= deployment %>")).to eq("some-deployment")
        expect(template.to_string_from_erb("<%= bosh_deployment %>")).to eq("some-bosh-deployment")
        expect(template.to_string_from_erb( "<%= deployment %> <%= diego_deployment %>")).to eq("some-deployment some-deployment-diego")
      end
    end

  end


  describe '#from_datadog' do
    it 'receives a json object from (purportedly datadog)' do

    end

    describe '#to_erb_from_string' do
      it "convert values back to erb vars" do
        expect(template.to_erb_from_string("some-deployment")).to eq("<%= deployment %>")
        expect(template.to_erb_from_string("some-bosh-deployment")).to eq("<%= bosh_deployment %>")
      end

      xit 'supports regex strings' do
        expect(template.to_erb_from_string("some-deployment")).to eq("<%= deployment %>")
        expect(template.to_erb_from_string("datadog.nozzle.asdf: { deployment: some-deployment }")).to
          eq("datadog.nozzle.asdf: { deployment: <%= metron_agent_deployment %> }")
      end

      it "can handle value overlaps" do
        expect(template.to_erb_from_string("some-deployment some-deployment-diego")).to eq(
            "<%= deployment %> <%= diego_deployment %>")
      end
    end

  end

end
