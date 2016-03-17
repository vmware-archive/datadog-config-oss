require "spec_helper"

describe TemplateHelper  do
  describe ".templates_for" do
    let(:template_type) { "template_helper" }
    let(:env) { "testing_env" }
    let(:workingdirectory) { File.expand_path(File.join(File.dirname(__FILE__), 'fixtures'))}
    subject() {TemplateHelper.templates_for(template_type, env, workingdirectory)}

    it { is_expected.to match_array(
        [
          /shared\/a.json.erb/,
          /shared\/b.json.erb/,
          /testing_env\/c.json.erb/
        ]
      )
    }
    # we expect items in `shared` to always be included

    # we'll go over the folders in `tags` and check them...
  end


end
