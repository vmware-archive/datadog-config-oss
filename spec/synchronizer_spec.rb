require "spec_helper"

describe Synchronizer do
  let(:fixtures) { File.join(File.dirname(__FILE__), "fixtures") }
  let(:logger) { Logger.new("/dev/null") }
  let(:synchronizer) { Synchronizer.new(File.join(fixtures, "config.yml"), "prod", logger) }
  let(:template) { File.join(fixtures, "screen_templates", "prod_screen.json.erb") }

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
end
