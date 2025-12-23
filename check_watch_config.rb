#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/yunsung/workspace/SecureOTP/SecureOTP.xcodeproj'
project = Xcodeproj::Project.open(project_path)

ios_target = project.targets.find { |t| t.name == 'SecureOTP' }
watch_target = project.targets.find { |t| t.name == 'SecureOTP Watch' }

if watch_target.nil?
  puts "❌ Watch target not found"
  exit 1
end

puts "✅ Watch target found: #{watch_target.name}"
puts "   Product type: #{watch_target.product_type}"

# Check if Watch target is a dependency of iOS target
dependencies = ios_target.dependencies.map(&:target).compact
watch_dependency = dependencies.find { |dep| dep.name == watch_target.name }

if watch_dependency
  puts "✅ Watch app is already configured as iOS app dependency"
else
  puts "⚠️  Watch app is NOT configured as iOS app dependency"
  puts "   Adding Watch target as dependency..."

  ios_target.add_dependency(watch_target)
  project.save

  puts "✅ Watch app dependency added successfully"
end

# Check build settings
puts "\n📋 Watch Target Build Settings:"
watch_target.build_configurations.each do |config|
  puts "  #{config.name}:"
  puts "    PRODUCT_BUNDLE_IDENTIFIER: #{config.build_settings['PRODUCT_BUNDLE_IDENTIFIER']}"
  puts "    SKIP_INSTALL: #{config.build_settings['SKIP_INSTALL']}"
end
