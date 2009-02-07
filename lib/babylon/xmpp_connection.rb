module Babylon
  require 'eventmachine'
  require 'nokogiri'  # used for SaxParsing  

  # This class is in charge of handling the network connection to the XMPP server.
  class NotConnected < Exception; end

  class XmppConnection < EventMachine::Connection

    def self.connect(config)
      Logger.info " -- Connecting to #{config['host']},#{config['port']} as #{self}"
      EventMachine::connect config['host'], config['port'], self, config
    end

    def reconnect host = @host, port = @port
      super
    end

    def unbind()
      Logger.warn " -- unbind (error=#{error?})"
      EventMachine::stop_event_loop
    end

    def initialize(config)
      @config = config
      super()
    end

    def receive_stanza(stanza)
      # If not handled by subclass (for authentication)
      CentralRouter.route self, stanza
    end

    def connection_completed
      super
      restart_stream
    end

    def restart_stream
      send_xml("<?xml version='1.0'?>")

      # And now, that we're connected, we must send a <stream>
      stream = REXML::Element.new("stream:stream")
      stream.add_namespace(stream_namespace)
      stream.add_attribute('xmlns:stream', 'http://etherx.jabber.org/streams')
      stream.add_attribute('to', stream_to)
      stream.add_attribute('version', "1.0")
      stream.add(REXML::Element.new('CUT-HERE'))
      @start_stream, @stop_stream = stream.to_s.split('<CUT-HERE/>')
      send_xml(@start_stream)

      @parser = XmppParser.new(&method(:receive_stanza))
    end

    def send_xml(xml)
      send_data xml.to_s
    end

    def send_data(data)
      Logger.debug " >> #{data}"
      super
    end

    def receive_data(data)
      Logger.debug " << #{data}"
      @parser.parse data
    end
  end

  class XmppParser < Nokogiri::XML::SAX::Document
    def initialize(&callback)
      @callback = callback
      @elem = nil
      @started = false
      super()
      @parser = Nokogiri::XML::SAX::Parser.new(self)
    end  

    def parse(data)
      @parser.parse data
    end

    def characters(string)
      @elem.add(REXML::Text.new(string)) if @elem
    end

    def cdata_block(string)
      @elem.add(REXML::Text.new(string)) if @elem
    end

    def start_element(name, attributes = [])
      e = REXML::Element.new(name)
      # Attributes is an array like [name, value, name, value]...
      (attributes.size / 2).times do |i|
        name, value = attributes[2 * i], attributes[2 * i + 1]
        
        # TODO: xmlns:...
        if name == 'xmlns'
          e.add_namespace value
        else
          e.attributes[name] = value
        end
      end
      
      @elem = @elem ? @elem.add(e) : e

      unless @started
        @started = true
        # <stream:stream> is different! We must callback now ;)
        @callback.call(@elem)
        @elem = nil
      end
    end

    def end_element(name)
      if @elem
        @callback.call(@elem) unless @elem.parent
        @elem = @elem.parent
      end
    end
  end

end
