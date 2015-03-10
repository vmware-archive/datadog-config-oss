class TemplateHelper
  def self.templates_for(template_type, env)
    shared_templates = Dir.glob(File.join(DIR, "#{template_type}_templates", 'shared', '**',  '*.json.erb'))
    env_specific_templates = Dir.glob(File.join(DIR, "#{template_type}_templates", env, '**', '*.json.erb'))

    shared_templates.concat env_specific_templates
  end
end
