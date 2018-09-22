require "dogapi"
require "yaml"
require "erb_context"
require "erb"
require "thread/pool"
require "logger"
require "json_organizer"
require 'template'

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

  def search_and_replace
    s_and_r = @env.fetch('search_and_replace')
    s_and_r.merge!({ environment: @env['environment'] })
    s_and_r
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
    additional = {
      dog: @dog
    }

    additional.merge!(@env)

    thresholds_file_path = thresholds_file(template_path)
    if File.exists? thresholds_file_path
      additional[:thresholds] = thresholds_for_yaml_file(thresholds_file_path)
    end

    begin
      template = Template.new(
        erb: File.read(template_path),
        search_and_replace: search_and_replace,
        additional: additional
      )
      JSON.parse(template.to_string)
    rescue => e
      puts "process_template error when processing #{template_path}"
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
      unless val.class==Array.new.class
        err_message = "#{val.fetch('errors', nil)}"
        unless err_message.empty?
          logger.error err_message
          raise err_message
        end
      end
      logger.warn "Operation timed out: retrying..." if code == -1
    end
    val
  end

  def get_json_template(id, template_output_file='/tmp/template.json.erb')
    code, obj = fetch_by_id(id)

    if code != "200"
      @logger.info "Failed to locate #{@environment} object (#{id}), skipping update"
      return
    end
    hash_cleanup(obj)
    template = convert_json_to_template(template_output_file, obj.sort_recursive)

    File.open(template_output_file, 'w') { |file| file.write(template) }
    logger.info "template .json.erb written to #{template_output_file}"
  end

  def convert_json_to_template(template_output_file, obj)
    derender(JSON.pretty_generate(obj) ).
      gsub(@environment, "<%= environment %>") # this is ugly and not safe
  end

  def fetch_by_id(id)
    raise NotImplementedError
  end

  def derender(str)
    template = Template.new(
      string: str,
      search_and_replace: @env.fetch('search_and_replace'),
      erb: nil
    )
    template.to_erb
  end

  def delete_all
    fetch_from_datadog.values.each do |id|
      # Our tls-test-env-dashboard
      if id != "923755"
        delete(id)
      end
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

  def hash_cleanup(hash)
    useless_keys= %W(id created creator modified
       state event_object silenced silenced_timeout_ts
       board_bgtype canonical_units
    )
    useless_keys.each { |key| hash.delete(key)}
  end
end
