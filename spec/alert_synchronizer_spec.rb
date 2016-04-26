require "spec_helper"

describe AlertSynchronizer do
  let(:fixtures) { File.join(File.dirname(__FILE__), "fixtures") }
  let(:logger) { Logger.new("/dev/null") }
  let(:synchronizer) { AlertSynchronizer.new(File.join(fixtures, "config.yml"), "prod", logger) }
  let(:template) { File.join(fixtures, "alert_templates", "some_alert.json.erb") }

  describe "#new" do
    it "uses the right credentials" do
      allow(Dogapi::Client).to receive(:new).with("my_api_key", "my_app_key")

      synchronizer
    end
  end

  describe "#fetch_from_datadog" do
    let(:alerts) do
      ["200",
        {"alerts"=>
          [{"id"=>273,
            "state"=>"No Data",
            "silenced"=>false,
            "message"=>" @pagerduty",
            "query"=>"avg(last_10m):max:system.load.5{host:alexsolo} > 6",
            "name"=>"Load AVG on host:alexsolo",
            "event_object"=>"f64854a9d66cd1eea9d77ec82588ff91",
            "notify_no_data"=>false,
            "creator"=>3658}]}]
    end

    it "returns alerts from datadog" do
      allow_any_instance_of(Dogapi::Client).to receive(:get_all_alerts).and_return(alerts)
      expect(synchronizer.fetch_from_datadog).to eq({ "Load AVG on host:alexsolo" => 273 })
    end

    it "retries in the face of adversity" do
      allow_any_instance_of(Dogapi::Client).to receive(:get_all_alerts).and_return([-1, {}], alerts)

      expect(synchronizer.fetch_from_datadog).to eq({ "Load AVG on host:alexsolo" => 273 })
    end
  end

  describe "#process_template" do
    it "processes a template" do
      alert = synchronizer.process_template(template)
      expect(alert.fetch("name")).to eq("prod alert name")
      expect(alert.fetch("message")).to eq("@pagerduty-backend")
      expect(alert.fetch("query")).to eq("some query")
    end
  end

  describe "#run" do
    it "creates a new alert when one does not already exist" do
      allow_any_instance_of(Dogapi::Client).to receive(:alert).with(
        "some query",
        :name => "prod alert name",
        :message => "@pagerduty-backend",
        :notify_no_data => false,
        :silenced => false)

      # no pre-existing alerts
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({})

      synchronizer.run([template])
    end

    it "updates alert that already exists" do
      allow_any_instance_of(Dogapi::Client).to receive(:update_alert).with(
        123,
        "some query",
        :name => "prod alert name",
        :message => "@pagerduty-backend",
        :notify_no_data => false,
        :silenced => false)

      # It already exists
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({ "prod alert name" => 123 })

      synchronizer.run([template])
    end
  end

  describe "#unknown_alert_names" do
    context "when there are no unknown alerts" do
      it "returns an empty list of names" do
        allow(synchronizer).to receive(:fetch_from_datadog).and_return({ "prod alert name" => 123 })

        expect(synchronizer.unknown_alert_names([template])).to eq([])
      end

      it "returns an empty list of ids" do
        allow(synchronizer).to receive(:fetch_from_datadog).and_return({ "prod alert name" => 123 })

        expect(synchronizer.unknown_alert_ids([template])).to eq([])
      end

      it "doesn't delete anything" do
        allow(synchronizer).to receive(:fetch_from_datadog).and_return({ "prod alert name" => 123 })

        expect_any_instance_of(Dogapi::Client).to_not receive(:delete_alert)
        synchronizer.delete_unknown_alerts([template])
      end

    end

    it "lists the alerts names that are present in datadog but not locally" do
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({ "prod alert name" => 123, "prod alert world" => 234 })

      expect(synchronizer.unknown_alert_names([template])).to eq(["prod alert world"])
    end

    it "lists the alerts ids that are present in datadog but not locally" do
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({ "prod alert name" => 123, "prod alert world" => 234 })

      expect(synchronizer.unknown_alert_ids([template])).to eq([234])
    end

    it "deletes the unknown dashboards" do
      allow_any_instance_of(Dogapi::Client).to receive(:delete_alert).with(234)
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({ "prod alert name" => 123, "prod alert world" => 234 })

      synchronizer.delete_unknown_alerts([template])
    end

    it "doesn't list alerts for other environments" do
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({ "prod alert name" => 123, "a1 alert name" => 234 })

      expect(synchronizer.unknown_alert_names([template])).to eq([])
    end
  end

  describe "get_json_template" do
    let(:alert) do
      [
        "200",
        {
          event_object: 54321,
          notify_audit: true,
          silenced: false,
          query: "avg(last_10m):avg:bosh.healthmonitor.system.healthy{deployment:some-bosh-deployment by {job,index} < 1",
          message: "A job in Bosh is being reported as unhealthy.",
          id: 53395,
          name: "prod Bosh: System health",
          no_data_timeframe: false,
          creator: 35324,
          notify_no_data: true,
          state: "OK",
          escalation_message: ""
        }
      ]
    end

    let(:written_files) { {} }

    let(:file_fake) do
      fake = double
      allow(fake).to receive(:write) { |file_data| file_data }
      fake
    end

    let(:template_output_path) { '/random/output/path/file.json.erb' }

    before do
      allow_any_instance_of(Dogapi::Client).to receive(:get_alert).with(54321).and_return(alert)

      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with(template_output_path, 'w') do |file_path, _, &block|
        template_data = block.call file_fake
        written_files[:template] = template_data
      end

      synchronizer.get_json_template(54321, template_output_path)
    end

    it "makes an erb template with deployment and bosh-deployment replaced by erb, and threshold values replaced with the threshold_value helper" do
      expected_template = <<JSON_ERB_TEMPLATE.strip
{
  "creator": 35324,
  "escalation_message": "",
  "event_object": 54321,
  "id": 53395,
  "message": "A job in Bosh is being reported as unhealthy.",
  "name": "<%= environment %> Bosh: System health",
  "no_data_timeframe": false,
  "notify_audit": true,
  "notify_no_data": true,
  "query": "avg(last_10m):avg:bosh.healthmonitor.system.healthy{deployment:<%= bosh_deployment %> by {job,index} < 1",
  "silenced": false,
  "state": "OK"
}
JSON_ERB_TEMPLATE
      expect(written_files[:template]).to eq(expected_template)
    end
  end
end

