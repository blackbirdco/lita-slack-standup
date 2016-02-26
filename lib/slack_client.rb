require 'slack-ruby-client'

module SlackClient
  def slack_client
    @slack_client ||= Slack::Web::Client.new
  end

  private

  def send_message(channel, message)
    slack_client.chat_postMessage(
      channel: channel,
      text: message,
      as_user: true
    )
  end
end
