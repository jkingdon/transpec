require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

namespace :ci do
  desc "#{Rake::Task['spec'].comment} for CI environment"
  task :spec do
    ENV['CI'] = 'true'

    ENV['CI_REPORTS'] = 'spec/reports'
    require 'ci/reporter/rake/rspec'
    Rake::Task['ci:setup:rspec'].invoke

    Rake::Task['spec'].invoke
  end
end

desc 'Check code style with RuboCop'
task :style do
  sh('rubocop')
end

desc 'Run RSpec and RuboCop'
task all: [:spec, :style]

desc 'Generate README.md'
task :readme do
  require 'erb'
  require 'transpec'
  erb = ERB.new(File.read('README.md.erb'), nil, '-')
  content = erb.result(binding)
  File.write('README.md', content)
end

task :abort_unless_latest_readme_is_committed => :readme do
  unless Transpec::Git.clean?
    warn 'Commit README.md before release.'
    exit 1
  end
end

Rake::Task[:release].enhance([:abort_unless_latest_readme_is_committed])

task default: :all
