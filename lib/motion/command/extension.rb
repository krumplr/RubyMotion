require 'motion/project/extension_generator'

module Motion; class Command
  class Extension < Command

    def self.extension_types
      [
        "ios-action-extension",
        "ios-custom-keyboard",
        "ios-document-picker",
        "ios-photo-editing",
        "ios-share-extension",
        "ios-today-extension",
        "ios-file-provider"
      ]
    end

    self.summary = 'Create a new iOS or OSX extension in the current project.'

    def self.description
      "Create a new iOS or OSX extension of the following types:\n\n" +
      self.extension_types.join("\n")
    end

    self.arguments = 'EXTENSION-TYPE EXTENSION-NAME'

    def initialize(argv)
      @extension_type = argv.shift_argument
      @extension_name = argv.shift_argument
      super
    end

    def validate!
      super
      help! "You need to specify the type of extension." unless @extension_type
      help! "The extension type #{@extension_type} is invalid." unless self.class.extension_types.include?(@extension_type)
      help! "A name for the extension is required." unless @extension_name
    end

    def run
      Motion::Project::ExtensionGenerator.new(@extension_type, @extension_name).generate
    end
  end
end; end
