$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rspec'
require 'webmock/rspec'

require 'dashboard_synchronizer'
require 'alert_synchronizer'
require 'screen_synchronizer'
require 'template_helper'
