require "dogapi"
require "yaml"
require "erb_context"
require "erb"
require "thread/pool"
require "logger"

class Synchronizer
  attr_reader :logger

  # @param [String] config_yml is the path to the config file
  # @param [String] environment is the top-level key in the yaml which defines the parameters to use
  def initialize(config_yml, environment, logger = Logger.new(STDOUT))
    @environment = environment

    @env = YAML.load_file(config_yml).fetch(environment)
    raise "Unknown environment '#{environment}'" if @env.nil?

    @env['environment'] = environment

    @api_key = @env.fetch('credentials').fetch('api_key')
    @app_key = @env.fetch('credentials').fetch('app_key')
    @dog = Dogapi::Client.new(@api_key, @app_key)
    @logger = logger
  end

  # Synchronize using the specified templates
  # @param [Array] templates is a list of paths to erb template files
  def run(templates)
    found = fetch_from_datadog

    logger.info "Synchronizing #{templates.size} templates..."
    pool = Thread.pool(8)

    templates.each do |path|
      logger.info "Template path: #{path}..."
      dashboard_or_alert = symbolize_keys(process_template(path))
      id = found[key_of(dashboard_or_alert)]

      if id
        do_in_pool(pool) { update(id, dashboard_or_alert) }
      else
        do_in_pool(pool) { create(dashboard_or_alert) }
      end
    end

    pool.shutdown
  end

  def thresholds_file(template_path)
    filename = File.basename template_path
    name = File.join(File.dirname(template_path), filename.split('.')[0] + "_thresholds.yml")
  end

  def thresholds_for_yaml_file(yaml_file_path)
    all_thresholds = YAML.parse_file(yaml_file_path).to_ruby
    default_thresholds = all_thresholds["prod"]
    thresholds = all_thresholds[@environment] || []

    default_thresholds.each do |default_threshold|
      unless thresholds.any? { |threshold| threshold["query"] == default_threshold["query"] && threshold["color"] == default_threshold["color"] }
        thresholds << default_threshold
      end
    end
  end

  # Processes an erb template
  # @param [String] template_path is a path to a single erb template
  # @return [Hash] the structure of the processed template
  def process_template(template_path)
    context = ErbContext.new(@env)
    context.dog = @dog

    thresholds_file_path = thresholds_file(template_path)
    if File.exists? thresholds_file_path
      context.thresholds = thresholds_for_yaml_file(thresholds_file_path)
    end

    # this returns the binding as it exists from the context's perspective
    # so all of the properties set on the ErbContext instance are exposed as
    # variables in the binding and therefore the ERB
    # TL;DR Magic.
    context_binding = context.instance_eval { binding }

    begin
      erbfile = ERB.new(File.read(template_path))
      erb = erbfile.result(context_binding)
      JSON.parse(erb)
    rescue => e
      puts "process_template error, #{e.message}"
      raise e
    end
  end

  # Override this to get the name key out of a fetched dashboard_or_alert
  def key_of(dashboard_or_alert)
    raise NotImplementedError
  end

  # Update the dashboard_or_alert at datadog
  def update(id, dashboard_or_alert)
    raise NotImplementedError
  end

  # Create the dashboard_or_alert at datadog
  def create(dashboard_or_alert)
    raise NotImplementedError
  end

  # @return [Hash] name key -> id
  def fetch_from_datadog
    raise NotImplementedError
  end

  def handle_datadog_errors
    code = -1
    while code == -1
      code, val = yield
      err_message = "#{val.fetch('errors', nil)}"
      unless err_message.empty?
        logger.error err_message
        raise err_message
      end
      logger.warn "Operation timed out: retrying..." if code == -1
    end
    val
  end

  def get_json_template(id, template_output_file='/tmp/template.json.erb')
    code, board = fetch_by_id(id)

    if code != "200"
      @logger.info "Failed to locate #{@environment} board (#{id}), skipping update"
      return
    end

    template = convert_json_to_template(template_output_file, board)

    File.open(template_output_file, 'w') { |file| file.write(template) }
    logger.info "template .json.erb written to #{template_output_file}"
  end

  def convert_json_to_template(template_output_file, board)
    JSON.pretty_generate(board).
      gsub(@env.fetch('bosh_deployment'), "<%= bosh_deployment %>").
      gsub(@env.fetch('deployment'), "<%= deployment %>").
      gsub(@environment, "<%= environment %>")
  end

  def fetch_by_id(id)
    raise NotImplementedError
  end

  def derender(string, option={erb_token: true})
    str = string.clone
    string_attributes = @env.select {|k,v| v.class == String && v.size > 5 }
    sorted_string_attributes = string_attributes.sort_by {|k, v| v.size * -1 }
    sorted_string_attributes.each do |k,v|
      if option[:erb_token]
        str.gsub!(v, "<%= #{k} %>" )
      else
        str.gsub!(v, k)
      end
    end
    str
  end

  def delete_all
    fetch_from_datadog.values.each do |id|
      delete(id)
    end
  end

  protected

  def symbolize_keys(hash)
    Hash[hash.map{ |(k,v)| [k.to_sym, v] }]
  end

  def unknown_datadog_object_names(local_object_names)
    remote_objects = fetch_from_datadog
    remote_object_names(remote_objects) - local_object_names
  end

  def unknown_datadog_object_ids(local_object_names)
    remote_objects = fetch_from_datadog

    (remote_object_names(remote_objects) - local_object_names).map do |name|
      remote_objects[name]
    end
  end

  def local_object_names(templates)
    templates.map do |template|
      processed_template = symbolize_keys(process_template(template))
      key_of(processed_template)
    end
  end


  private

  # Need to weed out objects pertaining to other environments (e.g. a1 doesn't care about tabasco)
  def remote_object_names(all_object_names)
    all_object_names.keys.select { |name| name.start_with?(@env["environment"]) }
  end

  def do_in_pool(pool)
    pool.process do
      handle_datadog_errors { yield }
    end
  end
end
