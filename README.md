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
    p datagram.header
    p datagram.request
    p datagram.objects
end

# Data is buffered and complete requests are passed to the callback
datagram = bacnet.read("\x81\xa\x0\x16\x1\x20\xff\xff\x0\xff\x10\x7\x3d\x8\x00SYNERGY")

```



## License and copyright

MIT
