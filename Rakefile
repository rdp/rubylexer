# Copyright (C) 2008  Caleb Clausen
# Distributed under the terms of Ruby's license.
require 'rubygems'
require 'hoe'

if $*==["test"]
  #hack to get 'rake test' to stay in one process
  #which keeps netbeans happy
#  Object.send :remove_const, :RubyLexer
  $:<<"lib"
  require 'rubylexer.rb'
  require "test/unit"
  require "test/code/regression.rb"
  Test::Unit::AutoRunner.run
  exit
end

require 'lib/rubylexer/version.rb'
 
   readme=open("README.txt")
   readme.readline("\n=== DESCRIPTION:")
   readme.readline("\n\n")
   desc=readme.readline("\n\n")
 
   hoe=Hoe.new("rubylexer", RubyLexer::VERSION) do |_|
     _.author = "Caleb Clausen"
     _.email = "rubylexer-owner @at@ inforadical .dot. net"
     _.url = ["http://github.com/coatl/rubylexer/", "http://rubyforge.org/projects/rubylexer/"]
     _.extra_deps << ['sequence', '>= 0.2.0']
     _.test_globs=["test/code/regression.rb"]
     _.description=desc
     _.summary=desc[/\A[^.]+\./]
     _.spec_extras={:bindir=>'',:rdoc_options=>'-x lib/rubylexer/test'}
     #_.rdoc_pattern=/\A(howtouse\.txt|testing\.txt|README\.txt|lib\/[^\/]*\.rb|lib\/rubylexer\/[^\d][^\/]*\.rb)\Z/
   end


