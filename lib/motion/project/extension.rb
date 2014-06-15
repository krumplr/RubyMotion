# encoding: utf-8

# Copyright (c) 2012, HipByte SPRL and contributors
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# require 'motion/project/xcode_config'
require 'motion/project/template/ios/config'
require 'motion/project/dependency'
require 'motion/project/parallel_builder'

module Motion; module Project;
  class Extension < IOSConfig

    variable :type, :attributes, :config

    def initialize(project_dir, build_mode, config)
      super(project_dir, build_mode)
      @config = config
      self.template = config.template
      case template
      when :ios
        @frameworks = ['UIKit', 'Foundation', 'CoreGraphics']
      when :osx
        @frameworks = ['AppKit', 'Foundation', 'CoreGraphics']
      end
    end

    def extension_path(platform)
      File.join(config.app_extensions_dir(platform), [config.identifier, @name, 'appex'].join('.'))
    end

    def vendor_project(path, type, opts={})
      opts[:force_load] = true unless opts[:force_load] == false
      @vendor_projects << Motion::Project::Vendor.new(File.join(project_dir, path), type, self, opts)
    end

    def unvendor_project(path)
      @vendor_projects.delete_if { |x| x.path == File.join(project_dir, path) }
    end

    def app_resources_dir(platform)
      extension_path(platform)
    end

    def platforms; config.platforms; end
    def local_platform; config.local_platform; end
    def deploy_platform; config.deploy_platform; end

    def supported_sdk_versions(versions)
      config.supported_sdk_versions(versions)
    end

    def common_plist_data(identifier)
      {
        'CFBundleDevelopmentRegion' => 'en',
        'CFBundleDisplayName' => @name,
        'CFBundleExecutable' => [identifier, @name].join('.'),
        'CFBundleIdentifier' => [identifier, @name].join('.'),
        'CFBundleInfoDictionaryVersion' => '6.0',
        'CFBundleName' => [identifier, @name].join('.'),
        'CFBundlePackageType' => 'XPC!',
        'CFBundleShortVersionString' => (@short_version || @version),
        'CFBundleSignature' => @bundle_signature,
        'CFBundleVersion' => @version
      }
    end

    def widget_extension_plist_data(platform, identifier)
      Motion::PropertyList.to_s({
        'LSApplicationCategoryType' => '',
        'NSExtension' => {
          'NSExtensionPrincipalClass' => 'TodayViewController',
          'NSExtensionPointIdentifier' => 'com.apple.widget-extension'
        }
      }.merge(common_plist_data(identifier)))
    end

    def keyboard_service_plist_data(platform, identifier)
      Motion::PropertyList.to_s({
        'NSExtension' => {
          'NSExtensionAttributes' => self.attributes,
          'NSExtensionPrincipalClass' => 'KeyboardViewController',
          'NSExtensionPointIdentifier' => 'com.apple.keyboard-service'
        }
      }.merge(common_plist_data(identifier)))
    end

    def share_services_plist_data(platform, identifier)
      Motion::PropertyList.to_s({
        'NSExtension' => {
          'NSExtensionAttributes' => self.attributes,
          'NSExtensionPrincipalClass' => 'ShareViewController',
          'NSExtensionPointIdentifier' => 'com.apple.share-services'
        }
      }.merge(common_plist_data(identifier)))
    end

    def photo_editing_plist_data(platform, identifier)
      Motion::PropertyList.to_s({
        'NSExtension' => {
          'NSExtensionAttributes' => self.attributes,
          'NSExtensionPrincipalClass' => 'PhotoEditingViewController',
          'NSExtensionPointIdentifier' => 'com.apple.photo-editing'
        }
      }.merge(common_plist_data(identifier)))
    end

    def fileprovider_nonui_photo_editing_plist_data(platform, identifier)
      Motion::PropertyList.to_s({
        'NSExtension' => {
          'NSExtensionAttributes' => self.attributes,
          'NSExtensionPrincipalClass' => 'FileProvider',
          'NSExtensionPointIdentifier' => 'com.apple.fileprovider-nonui'
        }
      }.merge(common_plist_data(identifier)))
    end

    def ui_services_plist_data(platform, identifier)
      Motion::PropertyList.to_s({
        'NSExtension' => {
          'NSExtensionAttributes' => self.attributes,
          'NSExtensionPrincipalClass' => 'ActionViewController',
          'NSExtensionPointIdentifier' => 'com.apple.ui-services'
        }
      }.merge(common_plist_data(identifier)))
    end

  end
end; end
