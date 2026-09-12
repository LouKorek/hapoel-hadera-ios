# Adds the LiveMatchWidget extension target to pwa-shell.xcodeproj.
#
# Run by CI before the build (bundle exec ruby scripts/add_widget_target.rb).
# The project file checked into the repo stays as PWABuilder generated it;
# this script derives the extension target from the files under
# LiveMatchWidget/ every time, so the target definition lives in code that
# can be reviewed rather than in hand-edited pbxproj identifiers. Idempotent.
require "xcodeproj"

PROJECT      = "pwa-shell.xcodeproj"
APP_TARGET   = "pwa-shell"
EXT_TARGET   = "LiveMatchWidget"
EXT_BUNDLE   = "il.co.hapoelhadera.app.LiveMatchWidget"
TEAM         = "YZTLGU87C6"
SHARED_FILE  = "pwa-shell/LiveMatchAttributes.swift"
CREST_FILE   = "pwa-shell/CrestStore.swift"
BRIDGE_FILE  = "pwa-shell/LiveActivityBridge.swift"

project = Xcodeproj::Project.open(PROJECT)
app = project.targets.find { |t| t.name == APP_TARGET } or abort("app target not found")
main_group = project.main_group

def file_ref(group, path)
  group.files.find { |f| f.path == path } || group.new_file(path)
end

# 1. New app-side sources on the app target (shared attributes, crest
#    store, bridge).
[SHARED_FILE, CREST_FILE, BRIDGE_FILE].each do |path|
  ref = file_ref(main_group, path)
  unless app.source_build_phase.files_references.include?(ref)
    app.source_build_phase.add_file_reference(ref)
    puts "added #{path} to #{APP_TARGET}"
  end
end

# 2. The extension target.
ext = project.targets.find { |t| t.name == EXT_TARGET }
if ext
  puts "#{EXT_TARGET} already present"
else
  ext = project.new_target(:app_extension, EXT_TARGET, :ios, "16.2")
  ext_group = main_group.find_subpath(EXT_TARGET, true)
  ext_group.set_source_tree("<group>")
  ext_group.set_path(EXT_TARGET)

  widget_src = ext_group.new_file("LiveMatchWidget.swift")
  ext.source_build_phase.add_file_reference(widget_src)
  ext.source_build_phase.add_file_reference(file_ref(main_group, SHARED_FILE))
  ext.source_build_phase.add_file_reference(file_ref(main_group, CREST_FILE))
  ext_group.new_file("Info.plist")
  ext_group.new_file("LiveMatchWidget.entitlements")

  ["WidgetKit", "SwiftUI"].each { |fw| ext.add_system_framework(fw) }

  ext.build_configurations.each do |cfg|
    s = cfg.build_settings
    s["PRODUCT_BUNDLE_IDENTIFIER"]   = EXT_BUNDLE
    s["PRODUCT_NAME"]                = EXT_TARGET
    s["INFOPLIST_FILE"]              = "#{EXT_TARGET}/Info.plist"
    s["IPHONEOS_DEPLOYMENT_TARGET"]  = "16.2"
    s["SWIFT_VERSION"]               = "5.0"
    s["TARGETED_DEVICE_FAMILY"]      = "1"
    s["SKIP_INSTALL"]                = "YES"
    s["DEVELOPMENT_TEAM"]            = TEAM
    s["CODE_SIGN_STYLE"]             = "Manual"
    s["CODE_SIGN_IDENTITY"]          = "Apple Distribution"
    s["MARKETING_VERSION"]           = app.build_configurations.first.build_settings["MARKETING_VERSION"]
    s["CURRENT_PROJECT_VERSION"]     = app.build_configurations.first.build_settings["CURRENT_PROJECT_VERSION"]
    s["ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME"] = "AccentColor"
    s["GENERATE_INFOPLIST_FILE"]     = "NO"
    s["LD_RUNPATH_SEARCH_PATHS"]     = ["$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks"]
    s["CODE_SIGN_ENTITLEMENTS"]      = "#{EXT_TARGET}/LiveMatchWidget.entitlements"
  end

  # 3. Embed it in the app.
  app.add_dependency(ext)
  embed = app.copy_files_build_phases.find { |p| p.name == "Embed Foundation Extensions" } ||
          app.new_copy_files_build_phase("Embed Foundation Extensions")
  embed.symbol_dst_subfolder_spec = :plug_ins
  bf = embed.add_file_reference(ext.product_reference)
  bf.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }
  puts "created #{EXT_TARGET}"
end

# The app must be at least iOS 16.2 to compile ActivityKit references; the
# code itself is guarded with #available so older devices still run it.
app.build_configurations.each do |cfg|
  v = cfg.build_settings["IPHONEOS_DEPLOYMENT_TARGET"].to_s
  cfg.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "16.2" if v.empty? || Gem::Version.new(v) < Gem::Version.new("16.2")
end

project.save
puts "project saved"
