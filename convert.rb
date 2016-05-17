#!/usr/bin/env ruby
# Use this to convert <%= deployment %> to <%= metron_agent_deployment %> when it comes from datadog.nozzle
# This is because datadog.nozzle uses the tagging provided by metron_agent, and this is distinct from the tagging provided by BOSH.

files = Dir.glob('**/*.json.erb')
files.each {|file|
  content = File.read(file);
  newcontent = content.gsub(/(datadog.nozzle.+deployment:\<\%\= )diego_deployment/,'\1metron_agent_diego_deployment')
  newcontent = newcontent.gsub(/(datadog.nozzle.+deployment:\<\%\= )deployment/,'\1metron_agent_deployment')
  File.write(file, newcontent)
}
