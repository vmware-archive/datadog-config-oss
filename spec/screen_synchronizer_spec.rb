require "spec_helper"

describe ScreenSynchronizer do
  let(:fixtures) { File.join(File.dirname(__FILE__), "fixtures") }
  let(:logger) { Logger.new("/dev/null") }
  let(:synchronizer) { ScreenSynchronizer.new(File.join(fixtures, "config.yml"), "prod", logger) }
  let(:template) { File.join(fixtures, "screen_templates", "prod_screen.json.erb") }

  describe "#fetch_from_datadog" do
    context "when updating production" do
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

      it "returns a hash that maps screen names to screen ids" do
        result = synchronizer.fetch_from_datadog
        expect(result).to eq({
          "prod BOSH Board" => 616,
          "prod Health" => 4322
        })
      end
    end
  end

  describe "unknown_screen" do
    context "when there are no unknown screens" do
      it "returns an empty list of names" do
        allow(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Health Test Upload" => 123})

        expect(synchronizer.unknown_screen_names([template])).to be_empty
      end

      it "returns an empty list of ids" do
        allow(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Health Test Upload" => 123})

        expect(synchronizer.unknown_screen_ids([template])).to be_empty
      end

      it "doesn't delete anything" do
        allow(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Health Test Upload" => 123})

        expect_any_instance_of(Dogapi::Client).to_not receive(:delete_screenboard)
        synchronizer.delete_unknown_screens([template])
      end
    end

    it "lists the screen that are present in datadog but not locally" do
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Health Test Upload" => 123, "prod Some Other Screen" => 234})

      expect(synchronizer.unknown_screen_names([template])).to eq(["prod Some Other Screen"])
    end

    it "lists the screen ids that are present in datadog but not locally" do
      allow(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Health Test Upload" => 123, "prod Some Other Screen" => 234})

      expect(synchronizer.unknown_screen_ids([template])).to eq([234])
    end

    it "deletes the unknown screens" do
      expect_any_instance_of(Dogapi::Client).to receive(:delete_screenboard).with(234)
      expect(synchronizer).to receive(:fetch_from_datadog).and_return({"prod Health Test Upload" => 123, "prod Some Other Screen" => 234})

      synchronizer.delete_unknown_screens([template])
    end

    it "doesn't list screens for other environments" do
      expect(synchronizer).to receive(:fetch_from_datadog).and_return({ "prod Health Test Upload" => 123, "a1 Some Screen" => 234 })

      expect(synchronizer.unknown_screen_names([template])).to eq([])
    end
  end

  describe "get_screen_json_template" do
     let(:written_files) { {} }
      let(:file_fake) do
        fake = double
        allow(fake).to receive(:write) { |file_data| file_data }
        fake
      end
      let(:template_output_path) { '/random/output/path/file.json.erb' }
      let(:thresholds_output_path) { '/random/output/path/file_thresholds.yml' }

      before do
        allow_any_instance_of(Dogapi::Client).to receive(:get_screenboard).with(54321).and_return(screenboard)

        allow(File).to receive(:open).and_call_original
        allow(File).to receive(:open).with(template_output_path, 'w') do |file_path, _, &block|
          template_data = block.call file_fake
          written_files[:template] = template_data
        end

        allow(File).to receive(:open).with(thresholds_output_path, 'w') do |file_path, _, &block|
          thresholds_data = block.call file_fake
          written_files[:thresholds] = thresholds_data
        end

      end

      def get_fixture(filename)
          File.read(File.expand_path('./fixtures/datadog/' + filename, File.dirname( __FILE__)))
      end

      context "erb template" do
        let(:screenboard) do
          eval get_fixture('screenboard_response_1.json')
        end

        it "makes an erb template with deployment, environment, and bosh-deployment replaced by erb, and threshold values replaced with the threshold_value helper" do
          expect_template = get_fixture('screenboard_response_1.json.erb').chomp("\n")
          synchronizer.get_json_template(54321, '/random/output/path/file.json.erb')
          expect(written_files[:template]).to eq(expect_template)
        end

        it "makes a thresholds value yml file with the threshold values extracted from the original json" do
          expect_thresholds = get_fixture('screenboard_response_1_thresholds.yml')
          synchronizer.get_json_template(54321, '/random/output/path/file.json.erb')
          expect(written_files[:thresholds]).to eq(expect_thresholds)
       end

      end

     context "screenboard notes" do
        let(:screenboard) do
          eval get_fixture('screenboard_response_2.json')
        end

        let(:dashboards) do
          eval get_fixture('dashboard_response_2.json')
        end

        let(:screenboards) do
          [
            "200",
            {
              "screenboards"=> [
                {
                  "resource"=>"/api/v1/screen/1234",
                  "id"=>1234,
                  "title"=>"some-deployment DEA Radiator"
                },
                {
                  "resource"=>"/api/v1/screen/2468",
                  "id"=>2468,
                  "title"=>"No specials"
                }
              ]
            }
          ]
        end

        before do
          allow_any_instance_of(Dogapi::Client).to receive(:get_dashboards).and_return(dashboards)
          allow_any_instance_of(Dogapi::Client).to receive(:get_all_screenboards).and_return(screenboards)
        end

        describe '#identity_target_link' do

        it 'change the note link for dashboards' do
          expect_dash = '/dash/dash/<%= lookup_note_asset(environment + \' DEA Radiator\', :dashboard) %>'
          expect(synchronizer.identify_target_link('/dash/dash/123456')).to eq(expect_dash)
        end

        it 'change the note link for screenboards' do
          expect_screen = '/screen/board/<%= lookup_note_asset( deployment + \' DEA Radiator\', :screenboard) %>'
          expect(synchronizer.identify_target_link('/screen/board/1234')).to eq(expect_screen)
        end

        it 'should handle screen titles with no special vars' do
          expect_screen = '/screen/board/<%= lookup_note_asset(\'No specials\', :screenboard) %>'
          expect(synchronizer.identify_target_link('/screen/board/2468')).to eq(expect_screen)
        end

        it 'should not change anything else' do
          expect(synchronizer.identify_target_link('http://google.com')).to eq('http://google.com')
        end

        end

        it 'makes an erb template with note dashboards replaced by erb helper' do
          synchronizer.get_json_template(54321, '/random/output/path/file.json.erb')
          expect(written_files[:template]).to eq(get_fixture('screenboard_response_2.json.erb').chomp("\n"))
        end

      end
  end
end
