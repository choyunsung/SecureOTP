#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/yunsung/workspace/SecureOTP/SecureOTP.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'SecureOTP' }
macos_target = project.targets.find { |t| t.name == 'SecureOTP macOS' }
watch_target = project.targets.find { |t| t.name == 'SecureOTP Watch' }

# Find the Shared group
shared_group = project.main_group['SecureOTP']['Shared']

# Create variant group for Localizable.strings
localizable_group = shared_group.new_variant_group('Localizable.strings')

# Add each language file
languages = ['en', 'ko', 'ja', 'zh']
languages.each do |lang|
  file_path = "#{lang}.lproj/Localizable.strings"
  file_ref = localizable_group.new_reference(file_path)
  file_ref.last_known_file_type = 'text.plist.strings'
  file_ref.name = lang
end

# Add LocalizationManager.swift
localization_manager_ref = shared_group.new_reference('LocalizationManager.swift')

# Add to targets
if target
  target.add_resources([localizable_group])
  target.add_file_references([localization_manager_ref])
end

if macos_target
  macos_target.add_resources([localizable_group])
  macos_target.add_file_references([localization_manager_ref])
end

if watch_target
  watch_target.add_resources([localizable_group])
  watch_target.add_file_references([localization_manager_ref])
end

# Update known regions
project.root_object.known_regions = ['en', 'Base', 'ko', 'ja', 'zh']

# Save the project
project.save

puts "✅ Successfully added localization files to Xcode project"
puts "   - Added Localizable.strings for: #{languages.join(', ')}"
puts "   - Added LocalizationManager.swift"
puts "   - Updated known regions"
