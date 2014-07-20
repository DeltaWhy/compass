#!/usr/bin/ruby
require 'cinch'
require 'dbm'
require './calc'
require './ellipse'

$db = DBM.open('compass.db', 0644, DBM::WRCREAT)
online = {}

bot = Cinch::Bot.new do
    configure do |c|
        c.server = 'brick.miscjunk.net'
        c.nick = 'Compass'
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

    on :message, "!quit" do |m|
        if m.user.nick == 'DeltaWhy'
            bot.quit("Bye")
        else
            m.reply "You're not the boss of me!"
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

    on :join do |m|
        online[m.user.nick.downcase] = true
        $db["seen:#{m.user.nick.downcase}"] = Time.now.to_i
    end
    on :leaving do |m|
        online[m.user.nick.downcase] = false
        $db["seen:#{m.user.nick.downcase}"] = Time.now.to_i
    end
end

bot.rule any: /\Ahello compass\z/i, [:direct, :private] => "hello" do |m,cmd|
    greetings = ["Hello", "Hi", "Howdy", "Hey"]
    "#{greetings.sample} #{m.user.nick}!"
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

bot.rule direct: /\A(.*) or (.*?)\??\z/i do |m,cmd|
    cmd =~ /\A(.*) or (.*?)\??\z/i
    [$1,$2].sample
end

bot.rule [:direct, :private] => // do |m,cmd|
    res = calc(cmd) rescue nil
    next unless res
    res = "#{m.user.nick}: #{res}" if m.message != cmd
    res
end

bot.rule [:direct, :private] => // do |m,cmd|
    "I don't know what you're talking about."
end

bot.start
online.each do |(k,v)|
    next unless v
    $db["seen:#{k}"] = Time.now.to_i
end
$db.close
