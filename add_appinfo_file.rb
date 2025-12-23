#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/yunsung/workspace/SecureOTP/SecureOTP.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'SecureOTP' }
macos_target = project.targets.find { |t| t.name == 'SecureOTP macOS' }

# Find the Shared group
shared_group = project.main_group['SecureOTP']['Shared']

# Add AppInfoView.swift
file_ref = shared_group.new_reference('AppInfoView.swift')

# Add to iOS target
if target
  target.add_file_references([file_ref])
end

# Add to macOS target
if macos_target
  macos_target.add_file_references([file_ref])
end

# Save the project
project.save

puts "✅ Successfully added AppInfoView.swift to Xcode project"
