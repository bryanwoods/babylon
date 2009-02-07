module Babylon
  
  class Runner
    require 'eventmachine'
    
    def self.run(config=nil)
      config = YAML::load(File.new('config.yaml')) unless config
      Logger::loglevel = config['loglevel'] || 'debug'
      @@run = true

      EventMachine.epoll
      EventMachine::run do
        connection = Babylon.const_get(config['connection'].intern || :ComponentConnection)
        connection.connect(config)
      end
    end

=begin
    # Like in RSpec's spec/runner.rb
    @@at_exit_hook_registered ||= false
    unless @@at_exit_hook_registered
      at_exit do
        @@run ||= false
        unless @@run
          config = YAML::load(File.new('config.yaml'))
          run(config)
        end
      end
      @@at_exit_hook_registered = true
    end
=end
  
  end
end
