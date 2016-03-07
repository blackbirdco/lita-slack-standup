module Lita
  module Handlers
    class SlackStandup < Handler
      include SlackClient

      config :channel

      def initialize(robot)
        super
        setup_redis_objects
      end

      route(/^standup\s+start$/, :standup_start, command: true, help: {t("help.start_cmd") => t("help.start_description") })

      def standup_start(message=nil)
        return if already_started? 
       
        in_standup.value = 'true'
        send_message(config.channel, t("sentence.start"))
        prewritten_standups_summary
        standup_next
      end

      route(/\Astandup\s+report\s*((.|\s)*)\z/, :standup_report, command: true, help: {t("help.report_cmd") => t("help.report_description")})

      def standup_report(message)
        save_standup message
        message.reply(t("sentence.report"))
      end

      route(/^standup\s+next$/, :standup_next, command: true, help: {t("help.next_cmd") => t("help.next_description")})

      def standup_next(message=nil)
        return unless standup_check?

        if standup_members.none? { |user, standup| standup.empty? }
          standup_end
        else
          next_attendee = select_next_standup
          send_message(config.channel, t("sentence.next", user: next_attendee)) 
          fill_standup(next_attendee)
        end
      end

      def reminder
        if in_standup.value == "true"
          spam_users_without_report("shame")
          standup_end
        end

        spam_users_without_report("reminder")
      end

      route(/^standup\s+ignore\s*(.*)$/, :standup_ignore, command: true, help: {t("help.ignore_cmd") => t("help.ignore_description")})

      def standup_ignore(message)
        user = extract_user(message)
        
        unless ignored_members.include? user
          ignored_members << user
          standup_members.delete(user)
        end
        
        message.reply(t("sentence.ignore", user: user))
      end

      route(/^standup\s+unignore\s*(.*)$/, :standup_unignore, command: true, help: {t("help.unignore_cmd") => t("help.unignore_description")})

      def standup_unignore(message)
        user = extract_user(message)
        
        if ignored_members.include? user
          ignored_members.delete(user)
          standup_members[user] = ''
        end
        
        message.reply(t("sentence.unignore",user: user))
      end

      route(/^standup\s+list$/, :standup_list, command: true, help: {t("help.list_cmd") => t("help.list_description")})

      def standup_list(message)
        message.reply(ignored_members.inject(t("sentence.list")) do |reply, user|
            reply += "#{user}  "
          end
        )
      end

      route(/^standup\s+end$/, :standup_end, command: true, help: {t("help.end_cmd") => t("help.end_description")})

      def standup_end(message=nil)
        return unless end_check?

        send_message(config.channel,t("sentence.end_standup"))
        in_standup.value = 'false'
        update_ids_to_members
        update_standup_members
      end

      private 

      def spam_users_without_report(translate_key)
        standup_members.each do |user, standup|
          send_message("@#{user}", t("sentence.#{translate_key}", user: user)) if standup.empty?
        end
      end

      def extract_user(message)
        message.matches[0][0].gsub('@','')
      end

      def already_started?
        if in_standup.value == 'true'
          send_message(config.channel, t("sentence.already_started"))
        end
        in_standup.value == 'true'
      end

      def end_check?
        if in_standup.value != 'true'
          send_message(config.channel, t("sentence.end_forbidden"))
        end
        in_standup.value == 'true'
      end

      def standup_check?
        if in_standup.value != 'true'
          send_message(config.channel, t("sentence.next_forbidden"))
        end
        in_standup.value == 'true'
      end

      def in_standup
        @in_standup ||= Redis::Value.new('in_standup', redis)
      end

      def ignored_members
        @ignored_members ||= Redis::List.new('ignored_members', redis)
      end

      def ids_to_members
        @ids_to_members ||= Redis::HashKey.new('ids_to_members', redis)
      end

      def standup_members
        @standup_members ||= Redis::HashKey.new('standup_members', redis)
      end

      def setup_redis_objects
        update_ids_to_members if ids_to_members.empty?
        update_standup_members if standup_members.empty?
      end

      def retrieve_channel
        slack_client.channels_list['channels'].find do |channel| 
          "##{ channel['name'] }" == config.channel 
        end
      end

      def fill_standup_members(members_list)
        members_list.each do |user_id|
          name = ids_to_members[user_id]
          unless ignored_members.include?(name) or name == 'automatic_user_ignore'
             standup_members[name] = ''
          end
        end
      end

      def update_standup_members
        standup_members.clear
        members_list = retrieve_channel['members']
        fill_standup_members(members_list)
      end

      def update_ids_to_members
        ids_to_members.clear
        slack_client.users_list['members'].each do |user|
          if user['deleted'] or user['is_bot']
            ids_to_members[user['id']] = 'automatic_user_ignore'
          else
            ids_to_members[user['id']] = user['name']
          end
        end
      end

      def prewritten_standups_summary
        standup_members.each do |user, standup|
          unless standup.empty?
            report = report_as_attachment(user, standup)
            slack_client.chat_postMessage(channel: config.channel, text:"", attachments: report, as_user: true)
          end
        end
      end

      def report_as_attachment(user,standup)
        [{
          fallback: t("sentence.fallback_standup_done",{user: user, standup: standup}),
          title: t("sentence.standup_done", user: user),
          text: standup,
          color: name_to_color(user) 
        }]
      end

      def name_to_color(name)
        name.each_char.map { |char| ((char.to_i(36)-10) % 16).to_s(16) }.
          join[0..5].rjust(6,'0')
      end

      def save_standup(message)
        member = message.user.mention_name
        standup_report = message.matches[0][0]
        standup_members[member] = standup_report
      end

      def fill_standup(member)
        standup_members[member] = t("sentence.standup_fill")
      end

      def select_next_standup
        standup_members.select{ |key,value| value.empty? }.first.first
      end
    end
    Lita.register_handler(SlackStandup)
  end
end
