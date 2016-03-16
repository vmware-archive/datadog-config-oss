module TemplateHelper
  def self.templates_for(template_type, env, working_directory, config_for_env)
    template_directory = File.join(working_directory, "#{template_type}_templates")
    shared_templates = find_templates(template_directory, 'shared')
    env_specific_templates = find_templates(template_directory, env)

    tags = config_for_env.fetch("tags", [])
    tags.each do |tag|
      shared_templates.concat find_templates(template_directory, "tags", tag)
    end

    shared_templates.concat env_specific_templates
  end

  def self.expand_path(*arr)
    File.join(arr)
  end

  def self.find_templates(*working_directory)
    Dir.glob(expand_path(working_directory, '**',  '*.json.erb'))
  end
end
