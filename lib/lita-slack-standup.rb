require "lita"
require "slack_client"

Lita.load_locales Dir[File.expand_path(
  File.join("..", "..", "locales", "*.yml"), __FILE__
)]

require "lita/handlers/slack_standup"

Lita::Handlers::SlackStandup.template_root File.expand_path(
  File.join("..", "..", "templates"),
 __FILE__
)
