# Ruby BACnet

Constructs [BACnet standard](https://en.wikipedia.org/wiki/BACnet) datagrams that make it easy to communicate with devices on BACnet/IP networks.
It does not implement the transport layer so you can use it with native ruby, eventmachine, celluloid, libuv or the like.

[![Build Status](https://travis-ci.org/acaprojects/ruby-bacnet.svg?branch=master)](https://travis-ci.org/acaprojects/ruby-bacnet)



## Install the gem

Install it with [RubyGems](https://rubygems.org/)

    gem install bacnet

or add this to your Gemfile if you use [Bundler](http://gembundler.com/):

    gem 'bacnet'



## Usage

```ruby
require 'bacnet'

bacnet = BACnet.new do |datagram|
    p datagram.header   # https://github.com/acaprojects/ruby-bacnet/blob/master/lib/bacnet/npdu.rb
    p datagram.request  # https://github.com/acaprojects/ruby-bacnet/blob/master/lib/bacnet/services.rb
    p datagram.objects  # https://github.com/acaprojects/ruby-bacnet/blob/master/lib/bacnet/objects.rb
end

# Data is buffered and complete requests are passed to the callback
datagram = bacnet.read("\x81\xa\x0\x16\x1\x20\xff\xff\x0\xff\x10\x7\x3d\x8\x00SYNERGY")

# There are helpers for generating messages
dgram = BACnet.confirmed_req(destination: 23, service: :read_property, destination_mac: 6)

obj1 = BACnet::ObjectIdentifier.new
obj1.type = :binary_value
obj1.instance_number = 5
dgram.add(obj1, tag: 0)   # Tag is the context specific tag

obj2 = BACnet::PropertyIdentifier.new
obj2.type = :present_value
dgram.add(obj2, tag: 1)

# send the binary datagram
send dgram.to_binary_s

```



## License and copyright

MIT
