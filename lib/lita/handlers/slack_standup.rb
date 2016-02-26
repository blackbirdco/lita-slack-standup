module Lita
  module Handlers
    class SlackStandup < Handler
      include SlackClient

      config :channel

      route(/^start\s*standup?/, :start_standup, command: true, help: {"start standup" => "Lance le standup." })

      def start_standup(message=nil)
        in_standup.value = 'true'
        setup_redis_objects
        send_message(config.channel, 'Hello <!channel> ! Le standup va commencer : )')
        prewritten_standups_summary
        next_standup
      end

      route(/^standup\s*(.*)$/, :standup, command: true, help: {"standup texte" => "Permet d'écrire son standup à l'avance ou pendant le tour d'un autre."})

      def standup(message)
        setup_redis_objects
        save_standup message
        message.reply("Ton standup est enregistré. Merci :)")
      end

      route(/^next\s*standup?/, :next_standup, command: true, help: {"next standup" => "Passe à l'utilisateur suivant et considère le standup précédent comme fait."})

      def next_standup(message=nil)
        if in_standup.value == 'true'
          if standup_members.none? { |user, standup| standup.empty? }
            end_standup
          else
            next_attendee = select_next_standup
            send_message(config.channel,"Bonjour <@#{next_attendee}> ! C'est à ton tour de parler.") 
            fill_standup(next_attendee)
          end
        else
          send_message(config.channel,"La commande n'est pas disponible en dehors d'un standup.")
        end
      end

      def reminder
        standup_members.each do |user, standup|
          send_message("@#{user}","Bonsoir <@#{user}> ! Tu peux donner ton standup pour demain. !standup 3615mavie") if standup.empty?
        end
      end

      route(/^ignore\s*(.*)$/, :ignore, command: true, help: {"ignore nom" => "Retire un utilisateur de la liste des personnes ayant à faire le standup"})

      def ignore(message)
        user = message.matches[0][0].gsub('@','')
        unless ignored_members.include? user
          ignored_members << user
          standup_members.delete(user)
        end
        message.reply("<@#{user}> est désormais ignoré jusqu'à nouvel ordre.")
      end

      route(/^unignore\s*(.*)$/, :unignore, command: true, help: {"unignore nom" => "Remet l'utilisateur dans la liste des personnes participant aux standups."})

      def unignore(message)
        user = message.matches[0][0].gsub('@','')
        if ignored_members.include? user
          ignored_members.delete(user)
          standup_members[user] = ''
        end
        message.reply("<@#{user}> est à nouveau inclus dans les standups.")
      end

      route(/^list\s*ignore?/, :list_ignore, command: true, help: {"list ignore" => "Liste les utilisateurs ignorés."})

      def list_ignore(message)
        reply = "Utilisateurs ignorés : "
        ignored_members.each do |user|
          reply += "#{user}  "
        end
        message.reply(reply)
      end

      private 

      def in_standup
        @in_standup ||= Redis::Value.new('in_standup', redis, marshal: true)
      end

      def ignored_members
        @ignored_members ||= Redis::List.new('ignored_members', redis)
      end

      def setup_redis_objects
          update_ids_to_members if ids_to_members.empty?
          update_standup_members if standup_members.empty?
      end

      def standup_members
        @standup_members ||= Redis::HashKey.new('standup_members', redis, marshal: true)
      end

      def retrieve_channel
        slack_client.channels_list['channels'].
          find do |channel| 
            "##{ channel['name'] }" == config.channel 
          end
      end

      def fill_standup_members(members_list)
        members_list.each do |user_id|
          name = ids_to_members[user_id]
          standup_members[name] = '' unless ignored_members.include?(name)
        end
      end

      def update_standup_members
        standup_members.clear
        members_list = retrieve_channel['members']
        fill_standup_members(members_list)
      end

      def ids_to_members
        @ids_to_members ||= Redis::HashKey.new('ids_to_members', redis, marshal: true)
      end

      def update_ids_to_members
        ids_to_members.clear
        slack_client.users_list['members'].each do |user|
          @ids_to_members[user['id']] = user['name']
        end
      end

      def prewritten_standups_summary
        standup_members.each do |user, standup|
            display_standup(user, standup) unless standup.empty?
        end
      end

      def display_standup(user, standup)
        send_message(config.channel, "#{user} a déjà renseigné son standup : \n #{standup}")         
      end

      def save_standup(message)
        member = message.user.mention_name
        standup_report = message.matches[0][0]
        standup_members[member] = standup_report
      end

      def fill_standup(member)
        standup_members[member] = 'Standup fait en live.'
      end

      def select_next_standup
        standup_members.select{ |key,value| value.empty? }.first.first
      end

      def end_standup
        in_standup.value = 'false'

        send_message(config.channel, "Et voilà ! C'est bon pour aujourd'hui. Merci tout le monde :parrot:")
        update_standup_members
        update_ids_to_members
      end

    end
    Lita.register_handler(SlackStandup)
  end
end
