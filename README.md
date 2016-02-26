# lita-standup

 - lita-standup is a gem for Lita (https://www.lita.io/), a chat bot written in ruby.
 - It handles standup meetings on slack (the sentences are in french for now).

## Installation

Add lita-standup to your Lita instance's Gemfile:

``` ruby
gem "lita-standup"
```

## Configuration

In your lita configuration file (lita_config.rb), add the lines :
``` ruby
Lita.congifure do |config|
  ## standup
  config.handlers.standup.channel = ENV['STANDUP_CHANNEL']
end
```

And set the environment variable STANDUP_CHANNEL, with the name of the channel where you want to held the standup.

## Usage

!start standup : launches the standup, prints the standups already filled and asks for someone else to report
!next standup : skips the current user and asks the next user to do his standup report
!standup <some standup report> : saves your standup. If you do it before the start of the standup, you won't be asked to report. The bot will displays your standup in your stead
!ignore <some user> : ignores an user for the standups
!unignore <some user> : unignores an user
!list ignore : list all ignored users

The standup stops when everyone has done his report or has been skipped.
