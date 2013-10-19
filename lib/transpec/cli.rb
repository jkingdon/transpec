# coding: utf-8

require 'transpec/commit_message'
require 'transpec/configuration'
require 'transpec/converter'
require 'transpec/dynamic_analyzer'
require 'transpec/file_finder'
require 'transpec/git'
require 'transpec/report'
require 'transpec/version'
require 'optparse'
require 'rainbow'

module Transpec
  class CLI
    CONFIG_ATTRS_FOR_CLI_TYPES = {
      expect_to_matcher: :convert_to_expect_to_matcher=,
      expect_to_receive: :convert_to_expect_to_receive=,
       allow_to_receive: :convert_to_allow_to_receive=,
             have_items: :convert_have_items=,
             deprecated: :replace_deprecated_method=
    }

    attr_reader :configuration, :forced, :generates_commit_message
    alias_method :forced?, :forced
    alias_method :generates_commit_message?, :generates_commit_message

    def self.run(args = ARGV)
      new.run(args)
    end

    def initialize
      @configuration = Configuration.new
      @forced = false
      @generates_commit_message = false
      @rspec_command = nil
      @report = Report.new
    end

    def run(args)
      paths = parse_options(args)
      fail_if_should_not_continue!

      process(paths)

      display_summary
      generate_commit_message if generates_commit_message?

      true
    rescue => error
      warn error.message
      false
    end

    def process(paths)
      dynamic_analyzer = DynamicAnalyzer.new(rspec_command: @rspec_command)

      puts "Running dynamic analysis with command \"#{dynamic_analyzer.rspec_command}\"..."
      runtime_data = dynamic_analyzer.analyze(paths)

      FileFinder.find(paths).each do |file_path|
        convert_file(file_path, runtime_data)
      end
    end

    def convert_file(file_path, runtime_data = nil)
      puts "Converting #{file_path}"

      converter = Converter.new(@configuration, runtime_data, @report)
      converter.convert_file!(file_path)

      @report.invalid_context_errors.concat(converter.invalid_context_errors)

      converter.invalid_context_errors.each do |error|
        warn_invalid_context_error(error)
      end
    rescue Parser::SyntaxError => error
      @report.syntax_errors << error
      warn_syntax_error(error)
    end

    # rubocop:disable MethodLength
    def parse_options(args)
      parser = OptionParser.new
      parser.banner = "Usage: transpec [options] [files or directories]\n\n"

      parser.on(
        '-f', '--force',
        'Force processing even if the current Git',
        'repository is not clean.'
      ) do
        @forced = true
      end

      parser.on(
        '-m', '--generate-commit-message',
        'Generate commit message that describes',
        'conversion summary. Only Git is supported.'
      ) do
        unless Git.inside_of_repository?
          fail '-m/--generate-commit-message option is specified but not in a Git repository'
        end

        @generates_commit_message = true
      end

      parser.on(
        '-d', '--disable TYPE[,TYPE...]',
        'Disable specific conversions.',
        'Available conversion types:',
        "  #{'expect_to_matcher'.bright} (from #{'should'.underline})",
        "  #{'expect_to_receive'.bright} (from #{'should_receive'.underline})",
        "  #{'allow_to_receive'.bright}  (from #{'stub'.underline})",
        "  #{'have_items'.bright} (to #{'expect(obj.size).to eq(x)'.underline})",
        "  #{'deprecated'.bright} (e.g. from #{'mock'.underline} to #{'double'.underline})",
        'These are all enabled by default.'
      ) do |types|
        types.split(',').each do |type|
          config_attr = CONFIG_ATTRS_FOR_CLI_TYPES[type.to_sym]
          fail ArgumentError, "Unknown conversion type #{type.inspect}" unless config_attr
          @configuration.send(config_attr, false)
        end
      end

      parser.on(
        '-n', '--negative-form FORM',
        "Specify negative form of #{'to'.underline} that is used",
        "in #{'expect(...).to'.underline} syntax.",
        "Either #{'not_to'.bright} or #{'to_not'.bright}.",
        "Default: #{'not_to'.bright}"
      ) do |form|
        @configuration.negative_form_of_to = form
      end

      parser.on(
        '-p', '--no-parentheses-matcher-arg',
        'Suppress parenthesizing argument of matcher',
        'when converting operator to non-operator',
        "in #{'expect'.underline} syntax. Note that it will be",
        'parenthesized even if this option is',
        'specified when parentheses are necessary to',
        'keep the meaning of the expression.',
        'By default, arguments of the following',
        'operator matchers will be parenthesized.',
        "  #{'== 10'.underline} to #{'eq(10)'.underline}",
        "  #{'=~ /pattern/'.underline} to #{'match(/pattern/)'.underline}",
        "  #{'=~ [1, 2]'.underline} to #{'match_array([1, 2])'.underline}"
      ) do
        @configuration.parenthesize_matcher_arg = false
      end

      parser.on(
        '-c', '--rspec-command COMMAND',
        'Specify command to run RSpec that is used',
        'for dynamic analysis.',
        'Default: "bundle exec rspec"'
      ) do |command|
        @rspec_command = command
      end

      parser.on('--no-color', 'Disable color in the output.') do
        Sickill::Rainbow.enabled = false
      end

      parser.on('--version', 'Show Transpec version.') do
        puts Version.to_s
        exit
      end

      args = args.dup
      parser.parse!(args)
      args
    end
    # rubocop:enable MethodLength

    private

    def fail_if_should_not_continue!
      return if forced?
      return unless Git.command_available?
      return unless Git.inside_of_repository?
      return if Git.clean?
      fail 'The current Git repository is not clean. Aborting.'
    end

    def display_summary
      puts

      unless @report.records.empty?
        puts 'Summary:'
        puts
        puts @report.colored_summary
        puts
      end

      puts @report.colored_stats
    end

    def generate_commit_message
      return if @report.records.empty?

      commit_message = CommitMessage.new(@report, ARGV)
      Git.write_commit_message(commit_message.to_s)

      puts
      puts 'Commit message was generated to .git/COMMIT_EDITMSG.'.color(:cyan)
      puts 'Use the following command for the next commit:'.color(:cyan)
      puts '    git commit -eF .git/COMMIT_EDITMSG'
    end

    def warn_syntax_error(error)
      warn "Syntax error at #{error.diagnostic.location}. Skipping the file.".color(:red)
    end

    def warn_invalid_context_error(error)
      message = error.message.color(:yellow) + $RS
      message << highlighted_source(error)
      warn message
    end

    def highlighted_source(error)
      filename = error.source_buffer.name.color(:cyan)

      line_number = error.source_range.line

      source = error.source_range.source_line
      highlight_range = error.source_range.column_range
      source[highlight_range] = source[highlight_range].underline

      [filename, line_number, source].join(':')
    end
  end
end
