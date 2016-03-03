$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require "rspec"
require "webmock/rspec"

require "dashboard_synchronizer"
require "alert_synchronizer"
require "screen_synchronizer"

def fixture_path(filename)
  File.join(File.dirname(__FILE__), "fixtures", filename)
end

def fixture_body(filename)
  File.read(fixture_path(filename))
end
