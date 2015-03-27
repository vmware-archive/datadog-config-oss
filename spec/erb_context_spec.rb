require 'spec_helper'

describe ErbContext do
  let(:dog) {
    instance_double(
      Dogapi::Client,
      get_all_screenboards:
        [ "200",
          { "screenboards"=> [
              {
                "resource"=>"/api/v1/screen/1234",
                "id"=>1234,
                "title"=>"sometitle"
              } ]
          } ],
      get_dashboards:
        ["200",
          { "dashes"=>
            [ {
                "title" => "somedashboard",
                "resource"=>"/api/v1/dash/123456",
                "id"=>"123456",
                "description"=>"The uptime of all the jobs"
              } ]
         } ]
    )
  }

  let(:context) {
    a = ErbContext.new
    a.dog = dog
    return a
  }

  describe '#lookup_note_asset' do
    it 'looks up screenboards from datadog' do
      expect(context.lookup_note_asset("sometitle", :screenboard)).to match("1234")
    end

    it 'fails gracefully when they do not exist' do
      expect(context.lookup_note_asset("nonexistent", :screenboard)).to match("")
    end

    it 'looks up dashboards from datadog' do
      expect(context.lookup_note_asset("somedashboard", :dashboard)).to match("123456")
    end

    it 'fails gracefully when they do not exist' do
      expect(context.lookup_note_asset("nonexistent", :dashboard)).to match("")
    end
  end

end
