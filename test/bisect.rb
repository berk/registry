#!/usr/bin/env ruby

# == Synopsis
#
# Run git bisect to find the commit that caused a test to fail.
#
# == Usage
#
# bisect.rb <good_revision> <test_filename> [options...]
#
# Options are:
#
#   -n <test_name>
#   -v, --verbose
#

require 'getoptlong'
require 'rdoc/ri/ri_paths'
require 'rdoc/usage'

@test_script = nil
@test_output = nil
def test_passes?
  raise 'No test!' unless @test_script
  puts "Running #{@test_script}..." if @verbose
  @test_output = `ruby #{@test_script}`
  puts @test_output if @verbose
  $? == 0
end

@git_result = nil
def git(cmd)
  puts ">> git #{cmd}" if @verbose
  @git_result = `git #{cmd}`
  puts @git_result if @verbose
  return true if  $? == 0
  puts @git_result unless @verbose
  false
end

@good_rev = @test_script = nil
@verbose = false

dash_param = false
ARGV.each_with_index do |arg, ii|
  if dash_param # read by previous iteration
    dash_param = false
  elsif arg =~ /^test[\/\\]/
    @test_script = arg

    unless File.exists?(@test_script)
      puts "Cannot find test filename #{@test_script}"
      exit
    end
  elsif arg == '-n'
    @test_script = "#{@test_script} -n #{ARGV[ii+1]}" if ARGV[ii+1]
    dash_param = true
  elsif arg == '-v' or arg == '--verbose'
    @verbose = true
  else
    @good_rev = arg
  end
end
  
if @good_rev.nil? or @test_script.nil?
  RDoc::usage
  exit
end

@git_result = `git status` # unreliable status code
unless @git_result =~ /nothing (added)? *to commit/
  puts @git_result
  puts "ERROR: Cannot bisect until status is clean!"
  exit
end

unless git("show #{@good_rev}")
  puts "ERROR: Invalid revision #{@good_rev}"
  exit
end

git('bisect start') or exit

begin
  first_run = true
  git("bisect good #{@good_rev}") or exit
  while true
    if test_passes?
      if first_run
        puts "ERROR: Test was expected to fail at this revision!"
        exit
      else
        git('bisect good') or exit
      end
    else
      git('bisect bad') or exit
    end

    system('rake externals')
    first_run = false
    break unless @git_result =~ /Bisecting/
  end

ensure
  puts @git_result unless @verbose
  git('bisect reset') or exit
end

puts "Done."

