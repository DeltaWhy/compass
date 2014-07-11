#!/usr/bin/ruby
require 'cinch'
require 'dbm'
require './calc'
require './ellipse'
#require 'yaml'
require 'open-uri'
require 'nokogiri'
require 'cgi'
require 'fileutils'



####   change these when you put it on the server!!  ####
$triggerFile = "/johnyburd/code/Ruby/compass/trigger.lst"
$responseFile = "/johnyburd/code/Ruby/compass/response.lst"
$db = DBM.open('compass.db', 0644, DBM::WRCREAT)
online = {}

bot = Cinch::Bot.new do
    configure do |c|
       # c.server = '192.168.1.90'
        c.server = 'irc.deltawhy.me'
        c.nick = 'Compass_II'
        c.channels = ['#minecraft']
    end

    @rules = []
    def rules; @rules; end

    def rule(kw, &block)
        rule = {block: block}
        kw.each do |k,v|
            if Symbol === k
                rule[k] = v
            elsif Array === k
                k.each {|k2| rule[k2] = v}
            end
        end
        rules.push(rule)
    end


    helpers do
      # Extremely basic method, grabs the first result returned by Google
          # or "No results found" otherwise
    def google(query)
        url = "http://www.google.com/search?q=#{CGI.escape(query)}"
        res = Nokogiri::HTML(open(url)).at("h3.r")

        title = res.text
        link = res.at('a')[:href]
        desc = res.at("./following::div").children.first.text
        rescue
            "No results found"
        else
            CGI.unescape_html "#{title} - #{desc} (#{link})"
     end
    end

           




    def match(rule, message, *args)
        puts "match(#{rule.inspect}, #{message}, #{args.inspect})"
        args.each do |kw|
            case rule[kw]
            when Regexp
                return true if rule[kw].match(message)
            when Array
                return true if rule[kw].include?(message)
            when String
                return true if rule[kw] == message
            end
        end
        false
    end

    on :message, /^!google (.+)/ do |m, query|
        m.reply google(query)
    end

    on :action, /\A(.*?)compass(.*?)\z/i do |m|
        m.reply ":O", true
    end

    on :message, /\A(!quit|goodbye, compass|bye, compass|cya, compass)\z/i do |m|
        if m.user.nick == 'DeltaWhy' || m.user.nick == 'johnyburd'
            m.reply "anything for you, #{m.user.nick}"
            bot.quit("Bye")
        else
            m.reply "You're not the boss of me!", true
        end
    end
 

    on :message do |m|
        direct = (m.message =~ /\Acompass[,:] (.+)\z/i)
        types = if !m.channel
                    [:private, :any]
                elsif direct
                    [:direct, :any]
                else
                    [:indirect, :any]
                end
        message = direct ? $1 : m.message
        bot.rules.each do |rule|
            res = rule[:block].call(m, message) if bot.match(rule, message, *types)
            if res
                m.reply res
                break
            end
        end
    end

    on :message, /^!msg (.+?) (.+)$/ do |m, who, text|
        User(who).send text
    end

    on :join do |m|
        online[m.user.nick.downcase] = true
        $db["seen:#{m.user.nick.downcase}"] = Time.now.to_i
        m.reply "HU"
    end
    on :leaving do |m|
        online[m.user.nick.downcase] = false
        $db["seen:#{m.user.nick.downcase}"] = Time.now.to_i
        Channel('#minecraft').send("bye #{m.user.nick}!")
    end

end

bot.rule any: /\A(hello|howdy|hi|hey|salutations|HU|how are you),? compass(!?)\z/i, [:direct, :private] => /\A(hello|howdy|hi|hey|salutations|HU|how are you)(!?)\z/i do |m,cmd|
    greetings = ["Hello", "Hi", "Howdy", "Hey", "Salutations","Greetings","Good to see you", "Thank you for blessing us with your presence", "Good day", "hi-ya", "welcome", "Howdy-do", "How goes it", "Hail", "Can't talk, zombies!"]
    "#{greetings.sample} #{m.user.nick}!"
end

bot.rule any: /\A((compass) (you're|your|youre|ur|you are) (.+))|((you're|your|youre|ur|you are) (.+,?) compass)\z/i, [:direct, :private] => /\A(you're|your|youre|ur|you are) (.*)\z/i do |m,cmd|
    comebacks = ["I know you are, #{m.user.nick}, but what am I?", "aw, thanks, #{m.user.nick[0,1]} <3", "thanks a lot, #{m.user.nick}.", "to you too!", "ookaay..."]
     "#{comebacks.sample}"
end

bot.rule any: /\A!(circle|ellipse) ([0-9]+)( ([0-9]+))?\z/, [:direct, :private] => /\A!?(circle|ellipse) ([0-9]+)( ([0-9]+))?\z/ do |m,cmd|
    cmd =~ /\A!?(circle|ellipse) ([0-9]+)( ([0-9]+))?\z/
    xdia = $2.to_i
    ydia = $4 ? $4.to_i : xdia
    next if xdia > 1000 || ydia > 1000
    res = ellipse(xdia, ydia)
    next unless res
    res = "#{m.user.nick}: #{res}" if m.message != cmd
    res
end

#bot.rule any: /\A!(go away|shutup|shut up|)\z/i, [:direct, :private] => /\A!?(go away|shutup|shut up)\z/i do |m,cmd|
 #   m.reply "fine. I'll go away for 30 seconds.  :'("
  #  sleep 30
#end

bot.rule any: /\A!seen ([A-Za-z0-9_-]+)\z/ do |m, cmd|
    cmd =~ /\A!seen ([A-Za-z0-9_-]+)\z/
    player = $1
    if online[player.downcase]
        "#{$1} is online since "+ Time.at($db["seen:#{player.downcase}"].to_i).to_s
    elsif $db["seen:#{player.downcase}"]
        "#{$1} was last seen "+ Time.at($db["seen:#{player.downcase}"].to_i).to_s
    else
        "I've never seen #{$1}."
    end
end

bot.rule any: /\A!roll ([0-9]*)d([0-9]+)\z/, [:direct, :private] => /\A!?roll ([0-9]*)d([0-9]+)\z/ do |m,cmd|
    cmd =~ /\A!?roll ([0-9]*)d([0-9]+)\z/
    n = $1.to_i
    n = 1 if n == 0
    sides = $2.to_i
    sum = 0
    n.times { sum += Random.rand(1..sides) }
    res = sum.to_s
    res = "#{m.user.nick}: #{res}" if m.message != cmd
    res
end

bot.rule any: /\A!flip\z/, [:direct, :private] => /\A!?flip\z/ do |m,cmd|
    res = ["heads","tails"].sample
    res = "#{m.user.nick}: #{res}" if m.message != cmd
    res
end

bot.rule any: /\A!?botsnack\z/i do |m,cmd|
    ":D"
end

bot.rule any: /\A!help\z/i do |m,cmd|
    "!isay [trigger] yousay [response]!seen [player] - see when a player was on\n!ellipse|circle [0-9] [0-9] - gives you some hand info on building circles\n!roll [0-9]d[0-9] - rolls (a) custom di(c)e\n!flip - flip a coin\n!echo [msg] - tests compass\n!msg [player] [msg] - sends a private msg from Compass"
end

bot.rule any: /\A(!thanks)|(thank(.*),? compass)\z/i, [:direct, :private] => /\Athanks\z/i do |m, cmd|
    welcomes = ["sure, #{m.user.nick[0,1]}", "any time, #{m.user.nick}", "no prob, #{m.user.nick[0,1]}", "it was nothing", ":D"]
    "#{welcomes.sample}"
end



bot.rule any: /\A!echo (.+)\z/, [:direct, :private] => /\A!?echo (.+)\z/ do |m, cmd|
    cmd =~ /\A!?echo (.+)\z/
    
    msg = $1
    
end
###
###
###

bot.rule any: /\A!delete (.*)\z/i, [:direct, :private] => /\A!?delete (.*)\z/i do |m, cmd|
    cmd =~ /\A!?delete (.*)\z/i
    command = $1
    lines = IO.readlines($triggerFile)

    lines.grep(/~#{command}`/i) {|x| $num = "#{lines.index(x)}".to_i}
    
    count = $num
    input_file = $responseFile
    second_input_file = $triggerFile
    output_file = "/johnyburd/code/Ruby/compass/tmp"
    
    string = IO.readlines(input_file)[count]

    if count.nil?
        "um, that's not a thing"
    else
                
         File.open(output_file, "w") do |out_file|
            File.foreach(second_input_file) do |line|
               out_file.puts line unless line.start_with? "~#{command}`"
            end
         end

          FileUtils.mv(output_file, second_input_file)

         File.open(output_file, "w") do |out_file|
            File.foreach(input_file) do |line|
               out_file.puts line unless line == "#{string}"
            end
         end

          FileUtils.mv(output_file, input_file)
        
        $num = nil
        "deleted '#{command}'"
    end
end


bot.rule any: /\A!isay (.*) yousay (.*)\z/i, [:direct, :private] => /\Awhen I say,? (.*?),? you say,? (.*)\z/i do |m, cmd|
    if cmd =~ /\A!isay (.*) yousay (.*)\z/i
    elsif cmd =~ /\Awhen I say,? (.*?),? you say,? (.*)\z/i
    end
    trig = $1
    resp = $2
    lines = IO.readlines($triggerFile)
    lines.grep(/~#{trig}`/i) {|x| $num = "#{lines.index(x)}".to_i}
    count = $num 

    if count.nil?
        
        File.open($triggerFile, 'a') do |file|
            file.puts "~#{trig}`"
        end
        File.open($responseFile, 'a') do |file|
            file.puts "#{resp}"
        end   
    
        "I'll say '#{resp}' when you say '#{trig}'"
    else 
        $num = nil
        "sorry #{trig} has already been set"
    end
end

bot.rule any: /\A([A-Za-z0-9_-]+) ([A-Za-z0-9_-]+) ([A-Za-z0-9_-]+)\z/i do |m, cmd|
    cmd =~/\A([A-Za-z0-9_-]+) ([A-Za-z0-9_-]+) ([A-Za-z0-9_-]+)\z/i
    if rand(7) == 1
        "'#{$1.capitalize} #{$2} #{$3.capitalize}' would make a good name for a band!"
    end
end

bot.rule any: /\A(.*)\z/i do |m, cmd|
    cmd =~ /\A(.*)\z/i
    lines = IO.readlines($triggerFile)
    lines.grep(/~#{$1}`/i) {|x|
    $num = "#{lines.index(x)}".to_i}
    if $num != nil
        lnnbr = $num
        $num = nil
        IO.readlines($responseFile)[lnnbr]

    elsif rand(15) == 1
        count = IO.readlines($responseFile).size
        IO.readlines($responseFile)[rand(count)]
    end
end



bot.rule [:direct, :private] => // do |m,cmd|
    res = calc(cmd) rescue nil
    next unless res
    res = "#{m.user.nick}: #{res}" if m.message != cmd
    res
end

bot.rule [:direct, :private] => // do |m,cmd|
    
    cmd =~ /\A.*\z/

   f = IO.readlines($responseFile)

    lines = IO.readlines($triggerFile)
    lines.grep(/~#{cmd}`/i) {|x|
    $num = "#{lines.index(x)}".to_i
    }
   

         
  
    
    if $num != nil
        lnnbr = $num
        $num = nil
        IO.readlines($responseFile)[lnnbr]
    else
        errors = ["I have no idea about that of which you speak", "what made you think that was a good idea?", "ummm... nope. got nothin'", "I'm not sure what you're talking about", "please try again (jk, go away)", "try !isay ... yousay ...", "that didn't make sense to me", "dummy, that's not a thing!"]
        "#{errors.sample}"
    end

end


online.each do |(k,v)|
    next unless v
    $db["seen:#{k}"] = Time.now.to_i
end
bot.start
$db.close
