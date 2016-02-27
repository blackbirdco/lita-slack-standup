require "lita-slack-standup"
require "lita/rspec"
require "webmock/rspec"

# A compatibility mode is provided for older plugins upgrading from Lita 3. Since this plugin
# was generated with Lita 4, the compatibility mode should be left disabled.
Lita.version_3_compatibility_mode = false

lib = File.expand_path('../lib/')
$:.unshift lib unless $:.include?(lib)

require "slack-ruby-client"
require "slack_client"
require "redis-objects"

# A compatibility mode is provided for older plugins upgrading from Lita 3. Since this plugin
# was generated with Lita 4, the compatibility mode should be left disabled.
Lita.version_3_compatibility_mode = false

#VCR.configure do |config|
#  config.cassette_library_dir = "spec/fixtures/vcr"
#  config.configure_rspec_metadata!
#  config.hook_into :webmock
#  config.filter_sensitive_data("<SLACK_LITA_TOKEN>") { ENV['SLACK_LITA_TOKEN'] }
#end

RSpec.configure do |c|
  c.after do
    Redis.new.flushdb
  end
end

