DIR = File.dirname(__FILE__)

$LOAD_PATH.unshift(File.join(DIR, "lib"))

require 'dashboard_synchronizer'
require 'alert_synchronizer'
require 'template_helper'
require 'screen_synchronizer'
require 'rspec/core/rake_task'
require 'json'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

ENV['RUBY_ENVIRONMENT'] ||= "cf_deployment"
task :push => [ENV['RUBY_ENVIRONMENT']+":push"]

CONFIG_PATH = File.join(DIR, "config/config.yml")
DASHBOARD_TEMPLATES = []
ALERT_TEMPLATES = []
SCREEN_TEMPLATES = []

def deployments
  config_yml=YAML.load_file(CONFIG_PATH)
  config_yml.keys
end

def push(env)
  config_for_env = YAML.load_file(CONFIG_PATH).fetch(env.to_s)

  DASHBOARD_TEMPLATES.concat(TemplateHelper.templates_for(:dashboard, env, DIR, config_for_env))
  SCREEN_TEMPLATES.concat(TemplateHelper.templates_for(:screen, env, DIR, config_for_env))
  ALERT_TEMPLATES.concat(TemplateHelper.templates_for(:alert, env, DIR, config_for_env))

  DashboardSynchronizer.new(CONFIG_PATH, env).run(DASHBOARD_TEMPLATES)
  ScreenSynchronizer.new(CONFIG_PATH, env).run(SCREEN_TEMPLATES)

  alert = AlertSynchronizer.new(CONFIG_PATH, env)
  alert.run(ALERT_TEMPLATES)
end

def client_for_env(env_name)
  env = YAML.load_file(CONFIG_PATH).fetch(env_name.to_s)

  api_key = env.fetch('credentials').fetch('api_key')
  app_key = env.fetch('credentials').fetch('app_key')
  dog = Dogapi::Client.new(api_key, app_key)
end

def console(env_name)
  require 'pry'

  client = client_for_env(env_name)
  env = YAML.load_file(CONFIG_PATH).fetch(env_name.to_s)

  puts "the config file for #{env_name} is in the variable 'env'"
  puts "an athenticated DataDog client is in the variable 'client'"

  binding.pry
end

def show_unknown_datadog_objects(env)
  puts
  puts "Unknown Alerts:"
  puts AlertSynchronizer.new(CONFIG_PATH, env).unknown_alert_names(ALERT_TEMPLATES)

  puts
  puts "Unknown Dashboards:"
  puts DashboardSynchronizer.new(CONFIG_PATH, env).unknown_dashboard_names(DASHBOARD_TEMPLATES)

  puts
  puts "Unknown Screens:"
  puts ScreenSynchronizer.new(CONFIG_PATH, env).unknown_screen_names(SCREEN_TEMPLATES)
end

def delete_env(env)
  puts "This will delete *all* alerts, dashboards, and screenboards for environment #{env}."
  print "Are you sure? [y/N] "
  choice = STDIN.gets.strip
  return unless choice == "y"

  puts
  puts "Deleting All Alerts"
  AlertSynchronizer.new(CONFIG_PATH, env).delete_all

  puts
  puts "Deleting All Dashboards"
  DashboardSynchronizer.new(CONFIG_PATH, env).delete_all

  puts
  puts "Deleting All Screens"
  ScreenSynchronizer.new(CONFIG_PATH, env).delete_all
end

def delete_unknown_datadog_objects(env)
  puts
  puts "Deleting Unknown Alerts"
  AlertSynchronizer.new(CONFIG_PATH, env).delete_unknown_alerts(ALERT_TEMPLATES)

  puts
  puts "Deleting Unknown Dashboards"
  DashboardSynchronizer.new(CONFIG_PATH, env).delete_unknown_dashboards(DASHBOARD_TEMPLATES)

  puts
  puts "Deleting Unknown Screens"
  ScreenSynchronizer.new(CONFIG_PATH, env).delete_unknown_screens(SCREEN_TEMPLATES)
end

def eval_alert(env, path)
  alert = AlertSynchronizer.new(CONFIG_PATH, env)
  puts JSON.pretty_generate(alert.process_template(path))
end

def eval_dashboard(env, path)
  dashboard = DashboardSynchronizer.new(CONFIG_PATH, env)
  puts JSON.pretty_generate(dashboard.process_template(path))
end

def eval_screen(env, path)
  screen = ScreenSynchronizer.new(CONFIG_PATH, env)
  puts JSON.pretty_generate(screen.process_template(path))
end

def build_tasks_for(env_name)
  fancy_env_name = env_name.to_s.capitalize

  namespace env_name.to_sym do
    desc "Push #{fancy_env_name} Datadog Config"
    task :push do
      push(env_name.to_s)
    end

    desc "List dashboards and alerts that are not represented in local templates for #{fancy_env_name}"
    task :list_unknown do
      show_unknown_datadog_objects(env_name.to_s)
    end

    desc "Delete dashboards and alerts that are not represented in local templates for #{fancy_env_name}"
    task :delete_unknown do
      puts "This does not work. Last time we ran it, it deleted a lot of things."
      #delete_unknown_datadog_objects(env_name.to_s)
    end

    desc "Evaluate the alert at path under the #{fancy_env_name} config and print to stdout"
    task :eval_alert, :path do |t, args|
      eval_alert(env_name.to_s, args[:path])
    end

    desc "Evaluate the dashboard at path under the #{fancy_env_name} config and print to stdout"
    task :eval_dashboard, :path do |t, args|
      eval_dashboard(env_name.to_s, args[:path])
    end

    desc "Evaluate the screen at path under the #{fancy_env_name} config and print to stdout"
    task :eval_screen, :path do |t, args|
      eval_screen(env_name.to_s, args[:path])
    end

    desc "Make a json template for the specified screen at the given file path"
    task :get_screen_json_erb, [:screen_id, :path] do |t, args|
      screen = ScreenSynchronizer.new(CONFIG_PATH, env_name.to_s)

      file_path = File.expand_path args[:path]
      screen.get_json_template(args[:screen_id], file_path)
    end

    desc "Make a json template for the specified dashboard at the given file path"
    task :get_dashboard_json_erb, [:dash_id, :path] do |t, args|
      dash = DashboardSynchronizer.new(CONFIG_PATH, env_name.to_s)

      file_path = File.expand_path args[:path]
      dash.get_json_template(args[:dash_id], file_path)
    end

    desc "Make a json template for the specified alert at the given file path"
    task :get_alert_json_erb, [:alert_id, :path] do |t, args|
      alert = AlertSynchronizer.new(CONFIG_PATH, env_name.to_s)

      file_path = File.expand_path args[:path]
      alert.get_json_template(args[:alert_id], file_path)
    end

    desc "A console with some useful variables"
    task :console do |t|
      console(env_name.to_s)
    end

    desc "emit data to datadog for testing purposes (note this WILL affect graphs and alerts)"
    task :emit, :metric do |t, args|
      metric = args[:metric]

      puts "\nwhat value for #{metric}:"
      value = STDIN.gets.strip

      puts "\nwhat host is #{metric} for (leave blank if none):"
      host = STDIN.gets.strip

      tags = []
      puts "\nenter tags as <key>:<value> (^D when done):"
      while
        tag = STDIN.gets
        tag.nil? ? break : tags << tag.strip
      end

      payload_options = { tags: tags }
      payload_options.merge!({ host: host }) if host.length > 0

      payload = [
        metric,
        value.to_f,
        payload_options
      ]

      puts "\n\nthe payload you are about to send is:"
      puts JSON.pretty_generate(payload)

      puts "\ndoes this look right [y/n]:"
      confirmation = STDIN.gets.strip

      if confirmation.downcase != 'y'
        puts "\ncancelling data emit"
        exit 1
      end

      client = client_for_env(env_name)
      puts client.emit_point(*payload)
    end

    desc "Delete an environment's Datadog setup: alerts, dashboards, and screenboards"
    task :delete_env do |t|
      delete_env(env_name.to_s)
    end
  end
end

deployments.each do |d|
  build_tasks_for(d)
end


DIEGO_DASHBOARD_TEMPLATES = Dir.glob(File.join(DIR, "dashboard_templates", "**", "diego_health_screen.json.erb"))
DIEGO_ENVIRONMENTS = YAML.load_file(CONFIG_PATH).select { |_,v| v["diego"] }.keys

namespace :diego do
  deployments.each do |d|
    namespace d do
      desc "Push #{d} Datadog Config"
      task :push do
        if DIEGO_ENVIRONMENTS.include?(d)
          puts "[INFO] Synchronizing Diego dashboard for '#{d}' environment"
          DashboardSynchronizer.new(CONFIG_PATH, d).run(DIEGO_DASHBOARD_TEMPLATES)
        else
          puts "[WARN] The environment '#{d}' does not have the Diego you're looking for..."
        end
      end
    end
  end

  desc "Push all Diego Datadog Configs"
  task :push do
    deployments.each { |k| Rake::Task["diego:#{k}:push"].execute }
  end
end

GARDEN_DASHBOARD_TEMPLATES = Dir.glob(File.join(DIR, "dashboard_templates", "**", "garden_health_screen.json.erb"))
GARDEN_ENVIRONMENTS = YAML.load_file(CONFIG_PATH).select { |_,v| v["garden"] }.keys

namespace :garden do
  deployments.each do |d|
    namespace d do
      desc "Push #{d} Datadog Config"
      task :push do
        if GARDEN_ENVIRONMENTS.include?(d)
          puts "[INFO] Synchronizing Garden dashboard for '#{d}' environment"
          DashboardSynchronizer.new(CONFIG_PATH, d).run(GARDEN_DASHBOARD_TEMPLATES)
        else
          puts "[WARN] The environment '#{d}' does not have the Garden you're looking for..."
        end
      end
    end
  end

  desc "Push all Garden Datadog Configs"
  task :push do
    deployments.each { |k| Rake::Task["garden:#{k}:push"].execute }
  end
end

GARDEN_BLACKBOX_DASHBOARD_TEMPLATES = Dir.glob(File.join(DIR, "dashboard_templates", "**", "garden_blackbox_screen.json.erb"))
GARDEN_BLACKBOX_ENVIRONMENTS = YAML.load_file(CONFIG_PATH).select { |_,v| v["garden_blackbox"] }.keys

namespace :garden_blackbox do
  deployments.each do |d|
    namespace d do
      desc "Push #{d} Datadog Config"
      task :push do
        if GARDEN_BLACKBOX_ENVIRONMENTS.include?(d)
          puts "[INFO] Synchronizing Garden dashboard for '#{d}' environment"
          DashboardSynchronizer.new(CONFIG_PATH, d).run(GARDEN_BLACKBOX_DASHBOARD_TEMPLATES)
        else
          puts "[WARN] The environment '#{d}' does not have the Garden you're looking for..."
        end
      end
    end
  end

  desc "Push all Garden Datadog Configs"
  task :push do
    deployments.each { |k| Rake::Task["garden:#{k}:push"].execute }
  end
end
