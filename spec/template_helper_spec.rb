require 'spec_helper'

describe TemplateHelper  do
  let(:template_type) { 'template_helper' }
  let(:env) { 'testing_env' }
  let(:workingdirectory) { File.expand_path(File.join(File.dirname(__FILE__), 'fixtures'))}
  let(:config_for_env) { { } }
  subject(:template_helper) {TemplateHelper.templates_for(template_type, env, workingdirectory, config_for_env)}

  describe '.templates_for' do
    it { is_expected.to match_array(
        [
          /shared\/a.json.erb/,
          /shared\/b.json.erb/,
          /testing_env\/c.json.erb/
        ]
      )
    }
  end

  describe '.find_templates' do
    subject() { TemplateHelper.find_templates(workingdirectory, 'template_helper_templates', 'testing_env') }
    it { is_expected.to match_array([/c.json.erb/]) }
  end


  describe '.expand_path' do
    subject() { TemplateHelper }
    it { expect(subject.expand_path('a', 'b')).to eq(File.join('a', 'b')) }
    it { expect(subject.expand_path('a')).to eq(File.join('a')) }
  end

  describe 'tagged environments' do
    context 'tag_a' do
      let(:config_for_env) { { 'tags' => [ 'tag_a' ] } }

      describe '.templates_for' do
        subject() { TemplateHelper.templates_for(template_type, env, workingdirectory, config_for_env) }
        it { is_expected.to match_array(
          [
            /shared\/a.json.erb/,
            /shared\/b.json.erb/,
            /testing_env\/c.json.erb/,
            /tags\/tag_a\/1.json.erb/
          ]
        )
        }
      end
    end
    context 'tag_a and tag_b' do
      let(:config_for_env) { { 'tags' => [ 'tag_a', 'tag_b' ] } }

      describe '.templates_for' do
        subject() { TemplateHelper.templates_for(template_type, env, workingdirectory, config_for_env) }
        it { is_expected.to match_array(
          [
            /shared\/a.json.erb/,
            /shared\/b.json.erb/,
            /testing_env\/c.json.erb/,
            /tags\/tag_a\/1.json.erb/,
            /tags\/tag_b\/2.json.erb/,
            /tags\/tag_b\/3.json.erb/
          ]
        )
        }
      end
    end
  end


end
