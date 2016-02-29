module Lita
  module Handlers
    class SlackStandup < Handler
      include SlackClient

      config :channel

      route(/^standup\s*start?/, :standup_start, command: true, help: {"standup start" => "Lance le standup." })

      def standup_start(message=nil)
        in_standup.value = 'true'
        setup_redis_objects
        send_message(config.channel, 'Hello <!channel> ! Le standup va commencer : )')
        prewritten_standups_summary
        standup_next
      end

      route(/\Astandup\s*report\s*(.*)\z/, :standup_report, command: true, help: {"standup report TEXT" => "Permet d'écrire son standup à l'avance ou pendant le tour d'un autre."})

      def standup_report(message)
        setup_redis_objects
        save_standup message
        message.reply("Ton standup est enregistré. Merci :)")
      end

      route(/^standup\s*next?/, :standup_next, command: true, help: {"standup next" => "Passe à l'utilisateur suivant et considère le standup précédent comme fait."})

      def standup_next(message=nil)
        setup_redis_objects
        return unless standup_check?

        if standup_members.none? { |user, standup| standup.empty? }
          standup_end
        else
          next_attendee = select_next_standup
          send_message(config.channel,"Bonjour <@#{next_attendee}> ! C'est à ton tour de parler.") 
          fill_standup(next_attendee)
        end
      end

      def reminder
        setup_redis_objects
        standup_members.each do |user, standup|
          send_message("@#{user}","Bonsoir <@#{user}> ! Tu peux donner ton standup pour demain. !standup report 3615mavie") if standup.empty?
        end
      end

      route(/^standup*\signore\s*(.*)$/, :standup_ignore, command: true, help: {"standup ignore USER" => "Retire un utilisateur de la liste des personnes ayant à faire le standup"})

      def standup_ignore(message)
        setup_redis_objects
        user = message.matches[0][0].gsub('@','')
        
        unless ignored_members.include? user
          ignored_members << user
          standup_members.delete(user)
        end
        
        message.reply("<@#{user}> est désormais ignoré jusqu'à nouvel ordre.")
      end

      route(/^standup*\sunignore\s*(.*)$/, :standup_unignore, command: true, help: {"standup unignore USER" => "Remet l'utilisateur dans la liste des personnes participant aux standups."})

      def standup_unignore(message)
        setup_redis_objects
        user = message.matches[0][0].gsub('@','')
        
        if ignored_members.include? user
          ignored_members.delete(user)
          standup_members[user] = ''
        end
        
        message.reply("<@#{user}> est à nouveau inclus dans les standups.")
      end

      route(/^standup\s*list?/, :standup_list, command: true, help: {"standup list" => "Liste les utilisateurs ignorés."})

      def standup_list(message)
        setup_redis_objects
        message.reply(
          ignored_members.inject("Utilisateurs ignorés : ") do |reply, user|
            reply += "#{user}  "
          end
        )
      end

      private 

      def standup_check?
        if in_standup.value != 'true'
          send_message(config.channel,"La commande n'est pas disponible en dehors d'un standup.")
        end
        in_standup.value == 'true'
      end

      def in_standup
        @in_standup ||= Redis::Value.new('in_standup', redis)
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
        slack_client.channels_list['channels'].find do |channel| 
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

      def standup_end
        in_standup.value = 'false'

        send_message(config.channel, "Et voilà ! C'est bon pour aujourd'hui. Merci tout le monde :parrot:")
        
        update_standup_members
        update_ids_to_members
      end
    end
    Lita.register_handler(SlackStandup)
  end
end
