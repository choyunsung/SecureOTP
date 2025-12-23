#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/yunsung/workspace/SecureOTP/SecureOTP.xcodeproj'
project = Xcodeproj::Project.open(project_path)

watch_target = project.targets.find { |t| t.name == 'SecureOTP Watch' }

if watch_target.nil?
  puts "❌ Watch target not found"
  exit 1
end

puts "📝 Updating Watch target build settings..."

watch_target.build_configurations.each do |config|
  # Set SKIP_INSTALL to NO so the Watch app is included in archives
  config.build_settings['SKIP_INSTALL'] = 'NO'

  # Ensure proper bundle identifier hierarchy
  if config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']
    puts "  #{config.name}: Setting SKIP_INSTALL to NO"
  end
end

project.save

puts "✅ Watch app configuration updated successfully"
puts "   The Watch app will now be automatically installed with the iOS app"
