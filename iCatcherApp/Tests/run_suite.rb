$:.unshift('Classes')
$:.unshift('StaticBinaries')

Dir.glob(File.expand_path('../**/*_test.rb', __FILE__)).each { |test| require test }

require 'Logger'