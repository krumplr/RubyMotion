require 'motion/error'

require 'erb'
require 'fileutils'

module Motion; module Project
  class ExtensionGenerator

    # For ERB
    attr_accessor :extension_name

    Paths = [
      File.expand_path(File.join(File.dirname(__FILE__), 'extension_templates')),
    ]

    ExtensionsPath = "extensions"

    def self.all_extensions
      @all_templates ||= begin
        h = {}
        Paths.map { |path| Dir.glob(path + '/*') }.flatten.select { |x| !x.match(/^\./) and File.directory?(x) }.each do |template_path|
          h[File.basename(template_path)] = template_path
        end
        h
      end
    end

    def initialize(extension_type, extension_name)
      @extension_type = extension_type
      @extension_name = extension_name

      @extension_directory = self.class.all_extensions[extension_type]

      unless @extension_directory
        raise InformativeError, "Cannot find extension `#{extension_type}' in " \
                                "#{Paths.join(' or ')}. Available extensions: " \
                                "#{self.class.all_extensions.keys.join(', ')}"
      end

      unless extension_name.match(/^[\w\s-]+$/)
        raise InformativeError, "Invalid extension name."
      end

      if File.exist?(File.join("plugins", extension_name))
        raise InformativeError, "Directory `#{ExtensionsPath}/#{extension_name}' already exists"
      end
    end

    def generate
      extension_path = File.join(ExtensionsPath, @extension_name)
      App.log 'Create', extension_path
      FileUtils.mkdir_p(extension_path)

      Dir.chdir(extension_path) do
        create_directories()
        create_files()
      end
    end

    private

    def extension_directory
      @extension_directory
    end

    def create_directories
      extension_files = File.join(extension_directory, 'files')
      Dir.glob(File.join(extension_files, "**/")).each do |dir|
        dir.sub!("#{extension_files}/", '')
        dir = replace_file_name(dir)
        FileUtils.mkdir_p(dir) if dir.length > 0
      end
    end

    def create_files
      extension_files = File.join(extension_directory, 'files')
      Dir.glob(File.join(extension_files, "**/*"), File::FNM_DOTMATCH).each do |src|
        dest = src.sub("#{extension_files}/", '')
        next if File.directory?(src)
        next if dest.include?(".DS_Store")

        dest = replace_file_name(dest)
        if dest =~ /(.+)\.erb$/
          App.log 'Create', "#{ExtensionsPath}/#{@extension_name}/#{$1}"
          File.open($1, "w") { |io|
            io.print ERB.new(File.read(src)).result(binding)
          }
        else
          App.log 'Create', "#{ExtensionsPath}/#{@extension_name}/#{dest}"
          FileUtils.cp(src, dest)
        end
      end
    end

    def replace_file_name(file_name)
      file_name = file_name.gsub("{name}", "#{@name}")
      file_name
    end

  end

end; end
