#!/usr/bin/ruby
require 'cinch'
require 'json'
require 'net/http'
require './calc'
require './ellipse'
require './serverping'
require_relative 'plugins/link_info'

bot = Cinch::Bot.new do
  configure do |c|
    c.server = '$server'
    c.password = '$password'
    c.nick = 'Compass'
    c.channels = ['#$channel']
    c.plugins.plugins = [Cinch::LinkInfo]
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
    if m.user.nick =~ /(Skype|Vanilla)Bot_*/ or m.user.nick =~ /EiraBot[0-9]*/
      begin
        m.message =~ /\A\<([^>]+)\> (.+)\z/
        message = $2
        nick = $1.split[0]
      rescue
        next
      end
    else
      message = m.message
      nick = m.user.nick
    end
    direct = (message =~ /\Acompass[,:] (.+)\z/i)
    types = if !m.channel
              [:private, :any]
            elsif direct
              [:direct, :any]
            else
              [:indirect, :any]
            end
    message = direct ? $1 : message
    bot.rules.each do |rule|
      res = rule[:block].call(m, message, nick) if bot.match(rule, message, *types)
      if res
        m.reply res
        if res =~ %r{(https?://.*?)(?:\s|$|,|\.\s|\.$)}
          bot.plugins[0].execute(m, $&)
        end
        break
      end
    end
  end
end

bot.rule any: /\Ahello compass\z/i, [:direct, :private] => "hello" do |m,cmd,nick|
  greetings = ["Hello", "Hi", "Howdy", "Hey"]
  "#{greetings.sample} #{nick}!"
end

bot.rule any: /\A!join (.+)\z/ do |m,cmd,nick|
  cmd =~ /\A!join (.+)\z/
  if nick == "DeltaWhy"
    bot.join $1
    ""
  else
    "You're not the boss of me!"
  end
end

bot.rule any: /\A!part( (.+))?\z/ do |m,cmd,nick|
  cmd =~ /\A!part( (.+))?\z/
  if nick == "DeltaWhy"
    if $2
      bot.part $2
      ""
    elsif m.channel
      bot.part m.channel
      ""
    else
      "What channel?"
    end
  else
    "You're not the boss of me!"
  end
end

bot.rule any: /\A!(circle|ellipse) ([0-9]+)( ([0-9]+))?\z/, [:direct, :private] => /\A!?(circle|ellipse) ([0-9]+)( ([0-9]+))?\z/ do |m,cmd,nick|
  cmd =~ /\A!?(circle|ellipse) ([0-9]+)( ([0-9]+))?\z/
  xdia = $2.to_i
  ydia = $4 ? $4.to_i : xdia
  next if xdia > 1000 || ydia > 1000
  res = ellipse(xdia, ydia)
  next unless res
  res = "#{nick}: #{res}" if m.message != cmd
  res
end

bot.rule any: /\A!roll ([0-9]*)d([0-9]+)\z/, [:direct, :private] => /\A!?roll ([0-9]*)d([0-9]+)\z/ do |m,cmd,nick|
  cmd =~ /\A!?roll ([0-9]*)d([0-9]+)\z/
  n = $1.to_i
  n = 1 if n == 0
  sides = $2.to_i
  sum = 0
  n.times { sum += Random.rand(1..sides) }
  res = sum.to_s
  res = "#{nick}: #{res}" if m.message != cmd
  res
end

bot.rule any: /\A!flip\z/, [:direct, :private] => /\A!?flip\z/ do |m,cmd,nick|
  res = ["heads","tails"].sample
  res = "#{nick}: #{res}" if m.message != cmd
  res
end

bot.rule any: /\A!?botsnack\z/i do |m,cmd,nick|
  ":D"
end

bot.rule any: /\A!disapprove( (.+))?\z/ do |m,cmd,nick|
  cmd =~ /\A!disapprove( (.+))?\z/
  res = ["(•_•)", "(;¬_¬)", "( ͠° ͟ʖ ͡°)", "(－‸ლ)"].sample
  res = "#{$2}: #{res}" if $2
  res
end

bot.rule any: /\A!shrug( (.+))?\z/ do |m,cmd,nick|
  cmd =~ /\A!shrug( (.+))?\z/
  res = ["¯\\_(ツ)_/¯"].sample
  res = "#{$2}: #{res}" if $2
  res
end

bot.rule any: /\A!(status|ping) ([a-z0-9.-]+)( ([0-9]+))?\z/ do |m,cmd,nick|
  cmd =~ /\A!(status|ping) ([a-z0-9.-]+)( ([0-9]+))?\z/
  begin
    resp = serverping($2, $4.to_i | 25565)
    playercount = resp['players']['online'] rescue "unknown"
    players = resp['players']['sample'].map(lambda x: x['name']).join(", ") rescue "#{playercount} players"
    description = resp['description']['text'] || resp['description'] rescue "Description not found"
    "#{description}. Online: #{players.empty? ? "no one" : players}."
  rescue => e
    p e
    "Couldn't ping #{$2}."
  end
end

bot.rule any: /\A!g(?:oogle)? (.+)\z/ do |m,cmd,nick|
  cmd =~ /\A!g(?:oogle)? (.+)\z/
  uri=URI.parse "http://ajax.googleapis.com/ajax/services/search/web?v=1.0&q=%s"\
    % URI.escape($1)
  req = Net::HTTP::Get.new(uri.request_uri)
  http = Net::HTTP.new(uri.host)
  http.read_timeout = 5
  http.open_timeout = 5
  res = http.start { |server|
    server.request(req)
  }
  result = JSON.parse(res.body)['responseData']['results'][0]['unescapedUrl']
  result
end

bot.rule any: /\A!(?:gis|i(?:mage)?) (.+)\z/ do |m,cmd,nick|
  cmd =~ /\A!(?:gis|i(?:mage)?) (.+)\z/
  uri=URI.parse "http://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=%s"\
    % URI.escape($+)
  req = Net::HTTP::Get.new(uri.request_uri)
  http = Net::HTTP.new(uri.host)
  http.read_timeout = 5
  http.open_timeout = 5
  res = http.start { |server|
    server.request(req)
  }
  result = JSON.parse(res.body)['responseData']['results'][0]['unescapedUrl']
  result
end

bot.rule any: /\A!w(?:iki)? (.+)\z/ do |m,cmd,nick|
  cmd =~ /\A!w(?:iki)? (.+)\z/
  uri=URI.parse "http://ajax.googleapis.com/ajax/services/search/web?v=1.0&q=%s"\
    % URI.escape("site:en.wikipedia.org #{$1}")
  req = Net::HTTP::Get.new(uri.request_uri)
  http = Net::HTTP.new(uri.host)
  http.read_timeout = 5
  http.open_timeout = 5
  res = http.start { |server|
    server.request(req)
  }
  result = JSON.parse(res.body)['responseData']['results'][0]['unescapedUrl']
  result
end

bot.rule any: /\A!s(?:o|tackoverflow)? (.+)\z/ do |m,cmd,nick|
  cmd =~ /\A!s(?:o|tackoverflow)? (.+)\z/
  uri=URI.parse "http://ajax.googleapis.com/ajax/services/search/web?v=1.0&q=%s"\
    % URI.escape("site:stackoverflow.com #{$1}")
  req = Net::HTTP::Get.new(uri.request_uri)
  http = Net::HTTP.new(uri.host)
  http.read_timeout = 5
  http.open_timeout = 5
  res = http.start { |server|
    server.request(req)
  }
  result = JSON.parse(res.body)['responseData']['results'][0]['unescapedUrl']
  result
end

bot.rule any: /\A!y(?:t|outube)? (.+)\z/ do |m,cmd,nick|
  cmd =~ /\A!y(?:t|outube)? (.+)\z/
  uri=URI.parse "http://ajax.googleapis.com/ajax/services/search/web?v=1.0&q=%s"\
    % URI.escape("site:youtube.com #{$1}")
  req = Net::HTTP::Get.new(uri.request_uri)
  http = Net::HTTP.new(uri.host)
  http.read_timeout = 5
  http.open_timeout = 5
  res = http.start { |server|
    server.request(req)
  }
  result = JSON.parse(res.body)['responseData']['results'][0]['unescapedUrl']
  result
end

bot.rule direct: /\A(.*) or (.*?)\??\z/i do |m,cmd,nick|
  cmd =~ /\A(.*) or (.*?)\??\z/i
  [$1,$2].sample
end

bot.rule [:direct, :private] => // do |m,cmd,nick|
  res = calc(cmd) rescue nil
  next unless res
  res = "#{nick}: #{res}" if m.message != cmd
  res
end

bot.rule [:direct, :private] => // do |m,cmd,nick|
  "I don't know what you're talking about."
end

bot.start
