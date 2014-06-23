config = require './config'
irc = require 'irc'
instapush = require 'instapush'
readline = require 'readline'
util = require 'util'
color = require('ansi-color').set

networks = {}
instapush.settings(config.instapush)

rl = readline.createInterface process.stdin, process.stdout
console_out = (msg...) ->
  process.stdout.clearLine()
  process.stdout.cursorTo 0
  console.log msg...
  rl.prompt true

for name, network of config.networks
  console_out 'Connecting to ' + color(name, 'green') + ': ' + network.channels.map((channel) -> color(channel, 'green')).join(color(', ', 'white'))
  networks[name] = new irc.Client network.connection.host, config.nick, {
    port: network.connection.port
    channels: network.channels
    userName: config.nick
    realName: config.nick
  }
  networks[name].friendlyName = name

  networks[name].once 'registered', ->
    console_out 'Connected to ' + color(@friendlyName, 'green')
  networks[name].addListener 'error', console_out
  networks[name].addListener 'message', (from, to, message) ->
    return if config.ignore.indexOf(from) > -1

    for trigger in config.triggers
      if message.toLowerCase().indexOf(trigger.toLowerCase()) > -1
        data =
          channel: to
          network: @friendlyName
          username: from
          message: message

        instapush.notify {
          event: 'mention'
          trackers: data
        }, (err, response) ->
          console_out "Error: #{err}" if err?
          console_out data
          console_out response

rl.prompt true
rl.on 'line', (line) ->
  line = line.split ' '
  command = line.shift()
  args = line.join ' '

  switch command
    when 'join'
      args = args.split ' '
      network = args.shift()
      channel = args.shift()

      return console_out color('Usage: join [network] [channel]', 'blue') if not network? or not channel?
      return console_out color('Invalid network', 'red') if not networks[network]?
      return console_out color('Invalid channel', 'red') if channel[0] isnt '#'

      console_out color("Joining #{channel}@#{network}", 'green')
      networks[network].join channel, ->
        console_out color("Joined #{channel}@#{network}", 'green')
    when 'part'
      args = args.split ' '
      network = args.shift()
      channel = args.shift()

      return console_out color('Usage: join [network] [channel]', 'blue') if not network? or not channel?
      return console_out color('Invalid network', 'red') if not networks[network]?
      return console_out color('Invalid channel', 'red') if channel[0] isnt '#'
      return console_out color("#{config.nick} isn't in #{channel}", 'red') if not networks[network].chans[channel]?

      console_out color("Parting from #{channel}@#{network}", 'green')
      networks[network].part channel, ->
        console_out color("Parted from #{channel}@#{network}", 'green')
    when 'quit'
      args = args.split ' '
      network = args.shift()
      message = args.join ' '

      return console_out color('Usage: quit [network] [message - optional]', 'blue') if not network?
      return console_out color('Invalid network', 'red') if not networks[network]? and network isnt '*'

      rl.question color('Are you sure you want to quit? (y/n) ', 'blue'), (input) ->
        return if input.toLowerCase() isnt 'y'

        networksToQuit = if network is '*' then Object.keys networks else [network]
        for network in networksToQuit
          networks[network].disconnect message
