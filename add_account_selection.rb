#!/usr/bin/env ruby
require 'xcodeproj'

project_path = '/Users/yunsung/workspace/SecureOTP/SecureOTP.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'SecureOTP' }
macos_target = project.targets.find { |t| t.name == 'SecureOTP macOS' }

shared_group = project.main_group['SecureOTP']['Shared']

file_ref = shared_group.new_reference('AccountSelectionView.swift')

if target
  target.add_file_references([file_ref])
end

if macos_target
  macos_target.add_file_references([file_ref])
end

project.save

puts "✅ Successfully added AccountSelectionView.swift to Xcode project"
