require "spec_helper"

describe Lita::Handlers::SlackStandup, lita_handler: true do

  let(:channel) { "#jambot-test" }
  let(:robot_name) { "jambot-test" }
  let(:sybil) { Lita::User.create(1000, name: "sybil") }
  let(:zaratan) { Lita::User.create(1001, name: "zaratan") }

  before(:all) do
    Slack.configure do |config|
      config.token = ENV['SLACK_LITA_TOKEN']
    end
    Lita.configure do |config|
      config.handlers.slack_standup.channel = '#jambot-test'
    end
  end

  let(:registry) do
    reg = Lita::Registry.new
    reg.register_handler(Lita::Handlers::SlackStandup)
    reg.configure do |config|
      config.robot.name = robot_name
      config.robot.alias = "!"
      config.robot.adapter = :slack
      config.handlers.slack_standup.channel = channel
    end

    reg
  end

  before do
    standup = Lita::Handlers::SlackStandup.new(robot)
    standup.send(:standup_members).clear
    standup.send(:ids_to_members).clear
    standup.send(:ignored_members).clear 
    ['jambot','slackbot','sybil_test'].each do |ignored_member|
      standup.send(:ignored_members) << ignored_member
    end
  end

  describe "when standup starts" do

    subject do 
      send_message("!start standup", as: sybil, from: channel)
    end

    it "starts standup", vcr: {cassette_name: 'start_standup'} do
      [ "Hello <!channel> ! Le standup va commencer : )",
        "Bonjour <@zaratan> ! C'est à ton tour de parler."
      ].each do |text|
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>text, :as_user=>true})
      end 
 
      subject 
    end

    it "annoys people only on working days" do
      #standup test that it's called on weekday
    end

    context "with pre-filled reports" do
      it "displays known reports", vcr: {cassette_name: 'standup_prefilled'} do
        send_message("!standup My standup report for testing purposes", as: sybil, from: channel)

	[ "Hello <!channel> ! Le standup va commencer : )",
	  "sybil a déjà renseigné son standup : \n My standup report for testing purposes",
	  "Bonjour <@zaratan> ! C'est à ton tour de parler."
	].each do |text|
	  expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>text, :as_user=>true})
	end

        subject
      end
      context "with all reports pre-filled", vcr: {cassette_name: 'standups_all_prefilled'} do
        it "displays the standups and ends the meeting" do
          send_message("!standup My standup report for testing purposes", as: sybil, from: channel)   
          send_message("!standup My standup report for testing purposes", as: zaratan, from: channel)   

 	  [ "Hello <!channel> ! Le standup va commencer : )",
	    "zaratan a déjà renseigné son standup : \n My standup report for testing purposes",
	    "sybil a déjà renseigné son standup : \n My standup report for testing purposes",
	    "Et voilà ! C'est bon pour aujourd'hui. Merci tout le monde :parrot:"
	  ].each do |text|
	    expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>text, :as_user=>true})       
          end

          subject
        end
      end
    end
  end

  describe "!standup command", vcr: {cassette_name: 'standup'} do
    subject do 
      send_message("!standup My standup report for testing purposes", as: sybil, from: channel)
    end

    context "when the user reports" do
      it "saves the report" do
        subject
        expect(replies.last).to eq("Ton standup est enregistré. Merci :)")
      end
    end
  end

  describe "!next standup command" do
    subject do
      send_message("!next standup", as: sybil, from: channel)
    end

    context "when its called oustide of standups", vcr: {cassette_name: 'next_standup_refused'} do
      it "is not available" do
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>"La commande n'est pas disponible en dehors d'un standup.", :as_user=>true})
       
        subject  
      end
    end

    context "when it's called during standup", vcr: {cassette_name: 'next_standup'} do
      it "asks the next user to report" do
        send_message("!start standup", as: sybil, from: channel)
 
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>"Bonjour <@sybil> ! C'est à ton tour de parler.", :as_user=>true})
       
        subject  
      end
    end
  end

  describe "!ignore user command", vcr: {cassette_name: 'ignore_user'} do

    subject do 
      send_message("!ignore sybil", as: sybil, from: channel)
      send_message("!next standup", as: sybil, from: channel)
    end

    it "ignores an user" do
      send_message("!start standup", as: sybil, from: channel)

      expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>"Et voilà ! C'est bon pour aujourd'hui. Merci tout le monde :parrot:", :as_user=>true})

      subject 
      expect(replies.last).to eq("<@sybil> est désormais ignoré jusqu'à nouvel ordre.")
    
    end
  end

  describe "!unignore user command", vcr: {cassette_name: 'unignore_user'} do

    subject do 
      send_message("!unignore sybil", as: sybil, from: channel)
      send_message("!next standup", as: sybil, from: channel)
    end

    it "unignores an user" do
      send_message("!start standup", as: sybil, from: channel)
      send_message("!ignore sybil", as: sybil, from: channel)

      expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>"Bonjour <@sybil> ! C'est à ton tour de parler.", :as_user=>true})

      subject 
      expect(replies.last).to eq("<@sybil> est à nouveau inclus dans les standups.")
    
    end
  end

end
