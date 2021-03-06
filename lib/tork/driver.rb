require 'set'
require 'tork/client'
require 'tork/engine'
require 'tork/config'

module Tork
class Driver < Engine

  def initialize
    super

    @herald = Client::Transceiver.new('tork-herald') do |changed_files|
      changed_files.each do |changed_file|
        # find and run the tests that correspond to the changed file
        visited = Set.new
        visitor = lambda do |source_file|
          Config.test_file_globbers.each do |regexp, globber|
            if regexp =~ source_file and globs = globber.call($~)
              Dir[*globs].each do |test_file|
                if visited.add? test_file
                  run_test_file test_file
                  visitor.call test_file
                end
              end
            end
          end
        end
        visitor.call changed_file

        # reabsorb text execution overhead if overhead files changed
        if Config.reabsorb_file_greps.any? {|r| r =~ changed_file }
          @client.send [:over, changed_file]
          reabsorb_overhead_files
        end
      end
    end

    reabsorb_overhead_files
  end

  def quit
    @herald.quit
    super
  end

  def run_all_test_files
    all_test_files = Dir[*Config.all_test_file_globs]
    if all_test_files.empty?
      warn "#{$0}: There are no test files to run."
    else
      run_test_files all_test_files
    end
  end

  def reabsorb_overhead_files
    reabsorb_overhead Config.overhead_load_paths, Dir[*Config.overhead_file_globs]
  end

end
end
