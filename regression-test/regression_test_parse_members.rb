#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Simple implementation of regression tests for xml generated by parse-members.rb
# N.B. Need to pre-populate reference xml files with those that have previously been generated.
# In other words, this is only useful for checking that any refactoring has not caused a regression in behaviour.
#

$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"

require "configuration"
require "people"

def compare_xml(test_file, ref_file)
  system("diff #{test_file} #{ref_file}")
  return if $CHILD_STATUS == 0

  # test = "regression_failed_test.xml"
  # ref = "regression_failed_ref.xml"
  # system("tidy -xml -o #{test} #{test_file}")
  # system("tidy -xml -o #{ref} #{ref_file}")
  system("opendiff #{test_file} #{ref_file}")
  puts "ERROR: #{test_file} and #{ref_file} don't match"
  exit
end

conf = Configuration.new

system("mkdir -p #{conf.members_xml_path}")

puts "Reading CSV data..."
people = PeopleCSVReader.read_members
PeopleCSVReader.read_all_ministers(people)
puts "Writing XML..."
people.write_xml("#{conf.members_xml_path}/people.xml", "#{conf.members_xml_path}/representatives.xml",
                 "#{conf.members_xml_path}/senators.xml", "#{conf.members_xml_path}/ministers.xml", "#{conf.members_xml_path}/divisions.xml")

ref_path = "#{File.dirname(__FILE__)}/../../ref"
compare_xml("#{conf.members_xml_path}/people.xml", "#{ref_path}/people.xml")
compare_xml("#{conf.members_xml_path}/representatives.xml", "#{ref_path}/representatives.xml")
compare_xml("#{conf.members_xml_path}/senators.xml", "#{ref_path}/senators.xml")
compare_xml("#{conf.members_xml_path}/ministers.xml", "#{ref_path}/ministers.xml")
compare_xml("#{conf.members_xml_path}/divisions.xml", "#{ref_path}/divisions.xml")
