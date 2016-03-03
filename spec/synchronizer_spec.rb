require "spec_helper"

describe Synchronizer do
  let(:logger) { Logger.new("/dev/null") }
  subject(:synchronizer) {
    Synchronizer.new(
      fixture_path('config.yml'),
      "prod",
      logger
    )
  }

  let(:template) { fixture_path(File.join("screen_templates", "prod_screen.json.erb")) }

  describe "#derender" do
    let(:screenboards_response) do
      [
        "200",
        {
          "screenboards" => [
            {"resource"=>"/api/v1/screen/616", "id"=>616, "title"=>"prod BOSH Board"},
            {"resource"=>"/api/v1/screen/4322", "id"=>4322, "title"=>"prod Health"}
          ]
        }
      ]
    end

    before do
      allow_any_instance_of(Dogapi::Client).to receive(:get_all_screenboards).and_return(screenboards_response)
    end

    it "covert values back to erb vars" do
       expect(synchronizer.derender("some-deployment")).to eq("<%= deployment %>")
       expect(synchronizer.derender("some-bosh-deployment")).to eq("<%= bosh_deployment %>")
    end

    it "can handle value overlaps" do
       expect(synchronizer.derender("some-deployment some-deployment-diego")).to eq(
         "<%= deployment %> <%= diego_deployment %>")
         # not "<%= deployment %> <%= deployment%>-diego"
    end
  end

  describe '#filter_json' do
    let(:raw_json) { fixture_body('convert_json_to_template/full_output.json') }
    let(:culled_output) { fixture_body('convert_json_to_template/culled_output.json') }
    subject() { synchronizer.filter_json(raw_json) }
    fit "produces filtered output" do
      expect(subject).to eq(culled_output)
    end

    fit 'produces valid json' do
      expect{JSON.parse(subject)}.to_not raise_error
    end
  end
end
