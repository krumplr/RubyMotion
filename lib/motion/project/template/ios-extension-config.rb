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

require 'motion/project/xcode_config'

module Motion; module Project;
  class IOSExtensionConfig < XcodeConfig
    register :'ios-extension'

    variable :device_family, :provisioning_profile, :manifest_assets

    def initialize(project_dir, build_mode)
      super
      @frameworks = ['UIKit', 'Foundation', 'CoreGraphics']
      @device_family = :iphone
      @manifest_assets = []
    end

    def platforms; ['iPhoneSimulator', 'iPhoneOS']; end
    def local_platform; 'iPhoneSimulator'; end
    def deploy_platform; 'iPhoneOS'; end

    def archs
      @archs ||= begin
        # By default, do not build with 64-bit, as it's still experimental.
        archs = super
        archs['iPhoneSimulator'].delete('x86_64')
        archs['iPhoneOS'].delete('arm64')
        archs
      end
    end

    def validate
      # manifest_assets
      if !(manifest_assets.is_a?(Array) and manifest_assets.all? { |x| x.is_a?(Hash) and x.keys.include?(:kind) and x.keys.include?(:url) })
        App.fail "app.manifest_assets should be an array of hashes with values for the :kind and :url keys"
      end

      super
    end

    def locate_compiler(platform, *execs)
      paths = [File.join(platform_dir(platform), 'Developer/usr/bin')]
      paths.unshift File.join(xcode_dir, 'Toolchains/XcodeDefault.xctoolchain/usr/bin')

      execs.each do |exec|
        paths.each do |path|
          cc = File.join(path, exec)
          return escape_path(cc) if File.exist?(cc)
        end
      end
      App.fail "Can't locate compilers for platform `#{platform}'"
    end

    def archive_extension
      '.ipa'
    end

    def codesign_certificate
      super('iPhone')
    end

    def provisioning_profile(name = /iOS Team Provisioning Profile/)
      @provisioning_profile ||= begin
        paths = Dir.glob(File.expand_path("~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision")).select do |path|
          text = File.read(path)
          text.force_encoding('binary') if RUBY_VERSION >= '1.9.0'
          text.scan(/<key>\s*Name\s*<\/key>\s*<string>\s*([^<]+)\s*<\/string>/)[0][0].match(name)
        end
        if paths.size == 0
          App.fail "Can't find a provisioning profile named `#{name}'"
        elsif paths.size > 1
          App.warn "Found #{paths.size} provisioning profiles named `#{name}'. Set the `provisioning_profile' project setting. Will use the first one: `#{paths[0]}'"
        end
        paths[0]
      end
    end

    def entitlements_data
      dict = entitlements
      if !distribution_mode
        # Required for gdb.
        dict['get-task-allow'] = true if dict['get-task-allow'].nil?
      end
      Motion::PropertyList.to_s(dict)
    end

    def common_flags(platform)
      simulator_version = begin
        flag = " -miphoneos-version-min=#{deployment_target}"
        if platform == "iPhoneSimulator"
          ver = xcode_version[0].match(/(\d+)/)
          if ver[0].to_i >= 5
            flag = " -mios-simulator-version-min=#{deployment_target}"
          end
        end
        flag
      end
      super + simulator_version
    end

    def cflags(platform, cplusplus)
      super + " -g -fobjc-legacy-dispatch -fobjc-abi-version=2"
    end

    def ldflags(platform)
      ldflags = super
      ldflags << " -fobjc-arc" if deployment_target < '5.0'
      ldflags
    end

    def bridgesupport_flags
      extra_flags = (OSX_VERSION >= 10.7 && sdk_version < '7.0') ? '--no-64-bit' : ''
      "--format complete #{extra_flags}"
    end

    def bridgesupport_cflags
      a = sdk_version.scan(/(\d+)\.(\d+)/)[0]
      sdk_version_headers = ((a[0].to_i * 10000) + (a[1].to_i * 100)).to_s
      "-miphoneos-version-min=#{sdk_version} -D__ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__=#{sdk_version_headers}"
    end

    def device_family_int(family)
      case family
        when :iphone then 1
        when :ipad then 2
        else
          App.fail "Unknown device_family value: `#{family}'"
      end
    end

    def device_family_ints
      ary = @device_family.is_a?(Array) ? @device_family : [@device_family]
      ary.map { |family| device_family_int(family) }
    end

    def app_bundle(platform)
      File.join(versionized_build_dir(platform), bundle_name + '.appex')
    end

    def app_bundle_executable(platform)
      File.join(app_bundle(platform), name)
    end

    def app_resources_dir(platform)
      app_bundle(platform)
    end

    def info_plist_data(platform)
      Motion::PropertyList.to_s({
        'MinimumOSVersion' => deployment_target,
        'CFBundleResourceSpecification' => 'ResourceRules.plist',
        'CFBundleSupportedPlatforms' => [deploy_platform],
        # TODO temp hack to get ints for Instruments, but strings for normal builds.
        'UIDeviceFamily' => device_family_ints.map { |x| ENV['__USE_DEVICE_INT__'] ? x.to_i : x.to_s },
        'DTXcode' => begin
          vers = xcode_version[0].gsub(/\./, '')
          if vers.length == 2
            '0' + vers + '0'
          else
            '0' + vers
          end
        end,
        'DTXcodeBuild' => xcode_version[1],
        'DTSDKName' => "#{platform.downcase}#{sdk_version}",
        'DTSDKBuild' => sdk_build_version(platform),
        'DTPlatformName' => platform.downcase,
        'DTCompiler' => 'com.apple.compilers.llvm.clang.1_0',
        'DTPlatformVersion' => sdk_version,
        'DTPlatformBuild' => sdk_build_version(platform),
      }.merge(generic_info_plist).merge(dt_info_plist).merge(info_plist)
       .merge({ 'CFBundlePackageType' => 'XPC!' }))
    end

    def manifest_plist_data
      return nil if manifest_assets.empty?
      Motion::PropertyList.to_s({
        'items' => [
          { 'assets' => manifest_assets,
            'metadata' => {
              'bundle-identifier' => identifier,
              'bundle-version' => @version,
              'kind' => 'software',
              'title' => @name
            } }
        ]
      })
    end

    def supported_sdk_versions(versions)
      versions.reverse.find { |vers| File.exist?(datadir(vers)) }
    end

    def sdk_build_version(platform)
      @sdk_build_version ||= begin
        sdk_path = sdk(platform)
        `#{locate_binary('xcodebuild')} -version -sdk '#{sdk_path}' ProductBuildVersion`.strip
      end
    end

    # TODO datadir should not depend on the template name
    def datadir(target=deployment_target)
      File.join(motiondir, 'data', 'ios', target)
    end

    # TODO datadir should not depend on the template name
    def supported_versions
      @supported_versions ||= Dir.glob(File.join(motiondir, 'data', 'ios', '*')).select{|path| File.directory?(path)}.map do |path|
        File.basename path
      end
    end

    def main_cpp_file_txt(spec_objs)
      main_txt = <<EOS
#import <UIKit/UIKit.h>
#include <objc/message.h>
#include <dlfcn.h>

extern "C" {
    void rb_define_global_const(const char *, void *);
    void rb_rb2oc_exc_handler(void);
    void rb_exit(int);
    void RubyMotionInit(int argc, char **argv);
EOS
      main_txt << <<EOS
}
EOS
      main_txt << <<EOS
int
main(int argc, char **argv)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int retval = 0;
EOS
    if ENV['ARR_CYCLES_DISABLE']
      main_txt << <<EOS
    setenv("ARR_CYCLES_DISABLE", "1", true);
EOS
    end
    main_txt << <<EOS
    RubyMotionInit(argc, argv);
EOS
    main_txt << <<EOS
    dlopen("/System/Library/PrivateFrameworks/PlugInKit.framework/PlugInKit", 0x2);
    retval = ((int(*)(id, SEL, int, char**))objc_msgSend)(NSClassFromString(@"PKService"), @selector(_defaultRun:arguments:), argc, argv);
    rb_exit(retval);
    [pool release];
    return retval;
}
EOS
    end
  end
end; end
