#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/yunsung/workspace/SecureOTP/SecureOTP.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the Watch target
watch_target = project.targets.find { |t| t.name == 'SecureOTP Watch' }

# Find the biometric file references
biometric_files = [
  'BiometricAuthManager.swift',
  'BiometricSettingsView.swift',
  'BiometricLockView.swift'
]

if watch_target
  # Get the source build phase
  sources_phase = watch_target.source_build_phase

  # Find and remove biometric files from Watch target
  biometric_files.each do |filename|
    build_file = sources_phase.files.find do |bf|
      bf.file_ref && bf.file_ref.path == filename
    end

    if build_file
      sources_phase.files.delete(build_file)
      puts "✅ Removed #{filename} from Watch target"
    end
  end
end

# Save the project
project.save

puts "\n✨ Successfully removed biometric files from Watch target"
puts "📱 Biometric authentication is only available on iOS and macOS"
puts "🔄 Please clean build folder (⇧⌘K) and rebuild (⌘B) in Xcode"
