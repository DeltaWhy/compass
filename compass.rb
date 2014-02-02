#!/usr/bin/ruby
require 'cinch'
require './calc'
require './ellipse'

bot = Cinch::Bot.new do
    configure do |c|
        c.server = 'cobblestone.miscjunk.net'
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
