$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rspec'
require 'webmock/rspec'

require 'dashboard_synchronizer'
require 'alert_synchronizer'
require 'screen_synchronizer'
require 'template_helper'
require 'json_organizer'
require 'template'
require 'pry'

RSpec.configure do |c|
  c.filter_run_including :focus => true
  c.run_all_when_everything_filtered = true

end
