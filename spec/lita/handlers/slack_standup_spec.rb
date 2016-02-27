require "spec_helper"

describe Lita::Handlers::SlackStandup, lita_handler: true do

  let(:channel) { "#jambot-test" }
  let(:robot_name) { "jambot-test" }
  let(:sybil) { Lita::User.create(1000, name: "sybil") }
  let(:zaratan) { Lita::User.create(1001, name: "zaratan") }

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
  
    stub_request(:post, "https://slack.com/api/users.list").
      with(:body => {"token"=>nil}, :headers => {'Accept'=>'application/json; charset=utf-8', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Slack Ruby Client/0.6.0'}).
      to_return(:status => 200, :body => '{"ok": true,"members":[
              {"id":"A","team_id":"AT","name":"sybil"}, {"id":"B","team_id":"BT","name":"zaratan"}]}', :headers => {})

    stub_request(:post, "https://slack.com/api/channels.list").
      with(:body => {"token"=>nil},:headers => {'Accept'=>'application/json; charset=utf-8', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Slack Ruby Client/0.6.0'}).
      to_return(:status => 200, :body => '{"ok":true,"channels":[{"id":"C","name":"jambot-test","is_channel":true,"members":["B","A"],"num_members":2}]}', :headers => {})
    
    stub_request(:post, "https://slack.com/api/chat.postMessage").
      with(:body => {"as_user"=>"true", "channel"=>"#jambot-test", "text"=>"Hello <!channel> ! Le standup va commencer : )", "token"=>nil},:headers => {'Accept'=>'application/json; charset=utf-8', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Slack Ruby Client/0.6.0'}).
      to_return(:status => 200, :body => '{"ok": true,"channel": "C","message": "Hello <!channel> ! Le standup va commencer : )"}', :headers => {})
  
    stub_request(:post, "https://slack.com/api/chat.postMessage").
      with(:body => {"as_user"=>"true", "channel"=>"#jambot-test", "text"=>"Bonjour <@zaratan> ! C'est à ton tour de parler.", "token"=>nil},:headers => {'Accept'=>'application/json; charset=utf-8', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type'=>'application/x-www-form-urlencoded', 'User-Agent'=>'Slack Ruby Client/0.6.0'}).
      to_return(:status => 200, :body => '{"ok": true,"channel": "C","message": "Bonjour <@zaratan> ! C\'est à ton tour de parler."}', :headers => {})
  end
  
  
  describe "when standup starts" do
    subject do 
      send_message("!standup start", as: sybil, from: channel)
    end

    it { is_expected.to route("!standup start") }  
    
    it "starts standup" do

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

      it "displays known reports" do
        [ "Hello <!channel> ! Le standup va commencer : )",
          "sybil a déjà renseigné son standup : \n My standup report for testing purposes",
          "Bonjour <@zaratan> ! C'est à ton tour de parler."
        ].each do |text|
          expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>text, :as_user=>true})
        end
        subject
      end
    
      context "with all reports pre-filled" do
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

  describe "!standup report command" do
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

    context "when its called oustide of standups" do
      it "is not available" do
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>"La commande n'est pas disponible en dehors d'un standup.", :as_user=>true})
        subject  
      end
    end

    context "when it's called during standup" do
      before do 
        send_message("!standup start", as: sybil, from: channel)
      end
        
      it "asks the next user to report" do
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with({:channel=>channel, :text=>"Bonjour <@sybil> ! C'est à ton tour de parler.", :as_user=>true})
        subject  
      end
    end
  end

  describe "!standup ignore user command" do

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

  describe "!standup unignore user command" do

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
