require "spec_helper"

describe DashboardSynchronizer do
  let(:fixtures) { File.join(File.dirname(__FILE__), "fixtures") }
  let(:logger) { Logger.new("/dev/null") }
  let(:synchronizer) { DashboardSynchronizer.new(File.join(fixtures, "config.yml"), "prod", logger) }
  let(:template) { File.join(fixtures, "dashboard_templates", "some_dashboard.json.erb") }

  describe "#new" do
    it "uses the right credentials" do
      allow(Dogapi::Client).to receive(:new).with("my_api_key", "my_app_key")

      synchronizer
    end
  end

  describe "#fetch_from_datadog" do
    let(:dashboards) do
      ["200",
       {"dashes" =>
        [{"title" => "My Dashboard",
          "resource" => "/api/v1/dash/2473",
          "id" => "2473",
          "description" => "An informative dashboard."},
          {"title" => "My First Metrics",
           "resource" => "/api/v1/dash/2552",
           "id" => "2552",
           "description" => "And they are marvelous."}
        ]}]
    end

    it "returns dashboards from datadog" do
      allow_any_instance_of(Dogapi::Client).to receive(:get_dashboards).and_return(dashboards)
      expect(synchronizer.fetch_from_datadog).to eq({"My Dashboard" => "2473", "My First Metrics" => "2552"})
    end

    it "retries in times of trouble" do
      allow_any_instance_of(Dogapi::Client).to receive(:get_dashboards).and_return([-1, {}], dashboards)

      expect(synchronizer.fetch_from_datadog).to eq({"My Dashboard" => "2473", "My First Metrics" => "2552"})
    end
  end

  describe "#process_template" do
    it "processes a template" do
      dash = synchronizer.process_template(template)
      expect(dash['title']).to eq("prod Some Dashboard")
      expect(dash['description']).to eq("Some description")
      expect(dash['graphs']).to eq([{
        "deployment" => "some-deployment",
        "services_deployment" => "services-deployment",
        "bosh_deployment" => "some-bosh-deployment"
      }])
      expect(dash['template_variables']).to match_array([{
        "default" => "*",
        "name" => "somename",
        "prefix" => "someprefix",
      }])
      expect(dash['gobbledygook_events'][0]["q"]).to eq("tags:deployment:prod start_deploy")
    end
  end

  describe "unknown_dashboard" do
    context "when there are no unknown dashboards" do
      it "returns an empty list of names" do
        allow(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Some Dashboard" => 123})

        expect(synchronizer.unknown_dashboard_names([template])).to be_empty
      end

      it "returns an empty list of ids" do
        allow(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Some Dashboard" => 123})

        expect(synchronizer.unknown_dashboard_ids([template])).to be_empty
      end

      it "doesn't delete anything" do
        allow(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Some Dashboard" => 123})

        expect_any_instance_of(Dogapi::Client).to_not receive(:delete_dashboard)
        synchronizer.delete_unknown_dashboards([template])
      end
    end

    it "lists the dashboard that are present in datadog but not locally" do
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Some Dashboard" => 123, "prod Some Other Dashboard" => 234})

      expect(synchronizer.unknown_dashboard_names([template])).to eq(["prod Some Other Dashboard"])
    end

    it "lists the dashboard ids that are present in datadog but not locally" do
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Some Dashboard" => 123, "prod Some Other Dashboard" => 234})

      expect(synchronizer.unknown_dashboard_ids([template])).to eq([234])
    end

    it "deletes the unknown dashboards" do
      expect_any_instance_of(Dogapi::Client).to receive(:delete_dashboard).with(234)
      expect(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Some Dashboard" => 123, "prod Some Other Dashboard" => 234})

      synchronizer.delete_unknown_dashboards([template])
    end

    it "doesn't list dashboards for other environments" do
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({ "prod Some Dashboard" => 123, "a1 Some Dashboard" => 234 })

      expect(synchronizer.unknown_dashboard_names([template])).to eq([])
    end
  end

  describe "#run" do
    let(:graphs) {
      [{
        "deployment" => "some-deployment",
        "services_deployment" => "services-deployment",
        "bosh_deployment" => "some-bosh-deployment"
      }]
    }
    let(:template_variables) {
      [{
        "default" => "*",
        "name" => "somename",
        "prefix" => "someprefix",
      }]
    }

    it "creates a new dashboard when one does not already exist" do
      expect_any_instance_of(Dogapi::Client).to receive(:create_dashboard).with("prod Some Dashboard", "Some description", graphs, template_variables)

      # no pre-existing dashboards
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({})

      synchronizer.run([template])
    end

    it "updates dashboard that already exists" do
      expect_any_instance_of(Dogapi::Client).to receive(:update_dashboard).with("123", "prod Some Dashboard", "Some description", graphs, template_variables)

      # It already exists
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Some Dashboard" => "123"})

      synchronizer.run([template])
    end

    context 'when there are no template_variables' do
      let(:template) { File.join(fixtures, "dashboard_templates", "no_template_vars_dashboard.json.erb") }
      let(:template_variables) { nil }

      it "creates a new dashboard when one does not already exist" do
        expect_any_instance_of(Dogapi::Client).to receive(:create_dashboard).with("prod Some Dashboard", "Some description", graphs, template_variables)

        # no pre-existing dashboards
        allow(synchronizer).to receive(:fetch_from_datadog).and_return({})

        synchronizer.run([template])
      end

      it "updates dashboard that already exists" do
        expect_any_instance_of(Dogapi::Client).to receive(:update_dashboard).with("123", "prod Some Dashboard", "Some description", graphs, template_variables)

        # It already exists
        allow(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Some Dashboard" => "123"})

        synchronizer.run([template])
      end
    end

  end

  describe "get_json_template" do
    let(:board) do
      [
        "200",
        "dash" => {
          "title" => "some-deployment Health",
          "description" => "some description",
          "graphs" => [
            {
              "title" => "some-deployment: stuff per second",
              "definition" => {
                "requests" => [
                  {
                    "q" => "this is the query for the environment: prod",
                    "stacked" => false
                  },
                  {
                    "q" => "this is the second query for the deployment: some-deployment",
                    "stacked" => false
                  }
                ],
                "events" => []
              }
            }
          ]
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
      allow_any_instance_of(Dogapi::Client).to receive(:get_dashboard).with(54321).and_return(board)

      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with(template_output_path, 'w') do |file_path, _, &block|
        template_data = block.call file_fake
        written_files[:template] = template_data
      end

      synchronizer.get_json_template(54321, '/random/output/path/file.json.erb')
    end

    it "makes an erb template with deployment and bosh-deployment replaced by erb, and threshold values replaced with the threshold_value helper" do
      expect(written_files[:template]).to eq(<<JSON_ERB_TEMPLATE.strip)
{
  "title": "<%= deployment %> Health",
  "description": "some description",
  "graphs": [
    {
      "title": "<%= deployment %>: stuff per second",
      "definition": {
        "requests": [
          {
            "q": "this is the query for the environment: <%= environment %>",
            "stacked": false
          },
          {
            "q": "this is the second query for the deployment: <%= deployment %>",
            "stacked": false
          }
        ],
        "events": [

        ]
      }
    }
  ]
}
JSON_ERB_TEMPLATE
    end
  end
end
