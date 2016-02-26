require "lita"
require "slack_client"

Lita.load_locales Dir[File.expand_path(
  File.join("..", "..", "locales", "*.yml"), __FILE__
)]

require "lita/handlers/standup"

Lita::Handlers::Standup.template_root File.expand_path(
  File.join("..", "..", "templates"),
 __FILE__
)
