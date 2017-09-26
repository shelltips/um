require 'etc'
require 'fileutils'
require 'forwardable'

class UmConfig
  extend Forwardable

  CONFIG_DIR_REL_PATH = '~/.um'.freeze
  CONFIG_FILE_REL_PATH = '~/.um/umconfig'.freeze

  UM_MARKDOWN_EXT = '.md'.freeze

  DEFAULT_CONFIG = {
    editor: ENV['EDITOR'] || 'vi',
    pages_directory: File.expand_path('~/.um/pages'),
    default_topic: 'shell',
    pages_ext: UM_MARKDOWN_EXT
  }.freeze

  def_delegators :@config, :each, :[], :has_key?

  attr_reader :file_path

  def initialize(config_path)
    @file_path = config_path
    @parsed_config = {}

    if File.exists? config_path
      @parsed_config = parse_config(config_path)
    end

    @config = DEFAULT_CONFIG.merge(@parsed_config)
  end

  def overridden?(key)
    @parsed_config.has_key?(key)
  end

  # Returns the path that should be used for a new um page.
  #
  # This method respects the `:pages_ext` config option.
  def new_page_path(page_name, topic)
    "#{topic_directory(topic)}/#{page_name}#{@config[:pages_ext]}"
  end

  # Returns the path to an existing page, or nil if no page exists.
  #
  # This method returns the first existing page file regardless of extension.
  def existing_page_path(page_name, topic)
    Dir["#{topic_directory(topic)}/#{page_name}.*"].first
  end

  def topic_directory(topic)
    "#{@config[:pages_directory]}/#{topic}"
  end

  # Sources the config file, returning the config environment as an UmConfig
  # object.
  def self.source
    config_path = File.expand_path(CONFIG_FILE_REL_PATH)
    config = UmConfig.new config_path

    write_pages_directory(config[:pages_directory])

    config
  end

  private

  def parse_config(path)
    config = {}

    parse_error_occurred = false
    File.foreach(path) do |line|
      if line[/(\w+) = ([\w \/\(\)\.]+)/]
        config[$1.downcase.to_sym] = $2
      elsif line.chomp.length > 0
        $stderr.puts "Unable to parse configuration file line #{$.}: " + 
          "'#{line.chomp}', skipping"
        parse_error_occurred = true
      end
    end

    $stderr.puts "Your configuration file is #{path}" if parse_error_occurred
    config
  end

  class << self
    private 

    # Cache the current pages directory in a file. This is used by the bash
    # completion script to avoid spinning up Ruby.
    def write_pages_directory(pages_directory_path)
      tmp_dir_path = '/var/tmp/um/' + Etc.getlogin
      FileUtils.mkdir_p tmp_dir_path

      tmp_file_path = tmp_dir_path + '/current.pagedir'
      unless File.exists?(tmp_file_path)
        File.write(tmp_file_path, pages_directory_path)
      end
    end
  end
end
