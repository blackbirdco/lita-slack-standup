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
      send_message("!standup start", as: sybil, from: channel)
    end

    it "starts standup", vcr: {cassette_name: 'standup_start'} do
      [ "Hello <!channel> ! Le standup va commencer : )",
        "Bonjour <@zaratan> ! C'est à ton tour de parler."
      ].each do |text|
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>text, :as_user=>true})
      end 
 
      subject 
    end

    context "with pre-filled report" do
      before do 
        send_message("!standup report My standup report for testing purposes", as: sybil, from: channel)
      end

      it "displays known reports", vcr: {cassette_name: 'standup_one_report_prefilled'} do
	[ "Hello <!channel> ! Le standup va commencer : )",
	  "sybil a déjà renseigné son standup : \n My standup report for testing purposes",
	  "Bonjour <@zaratan> ! C'est à ton tour de parler."
	].each do |text|
	  expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>text, :as_user=>true})
	end
        subject
      end
    
      context "with all reports pre-filled", vcr: {cassette_name: 'standup_all_reports_prefilled'} do
        before do
          send_message("!standup report My standup report for testing purposes", as: sybil, from: channel)   
          send_message("!standup report My standup report for testing purposes", as: zaratan, from: channel)   
        end

        it "displays the standups and ends the meeting" do
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

  describe "!standup report command", vcr: {cassette_name: 'standup_report'} do
    subject do 
      send_message("!standup report My standup report for testing purposes", as: sybil, from: channel)
    end

    it "saves the report" do
      subject
      expect(replies.last).to eq("Ton standup est enregistré. Merci :)")
    end
  end

  describe "!standup mext command" do
    subject do
      send_message("!standup next", as: sybil, from: channel)
    end

    context "when its called oustide of standups", vcr: {cassette_name: 'standup_next_refused'} do
      it "is not available" do
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>"La commande n'est pas disponible en dehors d'un standup.", :as_user=>true})
        subject  
      end
    end

    context "when it's called during standup", vcr: {cassette_name: 'standup_next'} do
      before do 
        send_message("!standup start", as: sybil, from: channel)
      end
        
      it "asks the next user to report" do
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>"Bonjour <@sybil> ! C'est à ton tour de parler.", :as_user=>true})
        subject  
      end
    end
  end

  describe "!standup ignore user command", vcr: {cassette_name: 'standup_ignore'} do

    before do
      send_message("!standup start", as: sybil, from: channel)
    end

    subject do 
      send_message("!standup ignore sybil", as: sybil, from: channel)
      send_message("!standup next standup", as: sybil, from: channel)
    end

    it "ignores an user" do
      expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>"Et voilà ! C'est bon pour aujourd'hui. Merci tout le monde :parrot:", :as_user=>true})
      subject 
      expect(replies.last).to eq("<@sybil> est désormais ignoré jusqu'à nouvel ordre.")
    end
  end

  describe "!standup unignore user command", vcr: {cassette_name: 'standup_unignore'} do

    before do
      send_message("!standup start", as: sybil, from: channel)
      send_message("!standup ignore sybil", as: sybil, from: channel)
    end

    subject do 
      send_message("!standup unignore sybil", as: sybil, from: channel)
      send_message("!standup next", as: sybil, from: channel)
    end

    it "unignores an user" do
      expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>"Bonjour <@sybil> ! C'est à ton tour de parler.", :as_user=>true})
      subject 
      expect(replies.last).to eq("<@sybil> est à nouveau inclus dans les standups.")
    end
  end
end
