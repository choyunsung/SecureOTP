#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/yunsung/workspace/SecureOTP/SecureOTP.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get all targets
ios_target = project.targets.find { |t| t.name == 'SecureOTP' }
macos_target = project.targets.find { |t| t.name == 'SecureOTP macOS' }
watch_target = project.targets.find { |t| t.name == 'SecureOTP Watch' }

# Find the Shared group
shared_group = project.main_group['SecureOTP']['Shared']

# Create file references for the biometric files
biometric_files = [
  'BiometricAuthManager.swift',
  'BiometricSettingsView.swift',
  'BiometricLockView.swift'
]

file_refs = biometric_files.map do |filename|
  shared_group.new_reference(filename)
end

# Add to iOS target
if ios_target
  ios_target.add_file_references(file_refs)
  puts "✅ Added biometric files to iOS target"
end

# Add to macOS target
if macos_target
  macos_target.add_file_references(file_refs)
  puts "✅ Added biometric files to macOS target"
end

# Add to Watch target
if watch_target
  watch_target.add_file_references(file_refs)
  puts "✅ Added biometric files to Watch target"
end

# Save the project
project.save

puts "\n✨ Successfully added biometric files to Xcode project:"
biometric_files.each do |file|
  puts "   - #{file}"
end
puts "\n📱 Targets updated: iOS, macOS, Watch"
puts "🔄 Please clean build folder (⇧⌘K) and rebuild (⌘B) in Xcode"
