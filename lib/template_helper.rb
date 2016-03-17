module TemplateHelper
  def self.templates_for(template_type, env, working_directory)
    shared_templates = Dir.glob(File.join(working_directory, "#{template_type}_templates", 'shared', '**',  '*.json.erb'))
    env_specific_templates = Dir.glob(File.join(working_directory, "#{template_type}_templates", env, '**', '*.json.erb'))

    shared_templates.concat env_specific_templates
  end
end
