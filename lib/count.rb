# frozen_string_literal: true

class Count
  attr_reader :minor, :major

  def initialize(major = 1, minor = 1)
    @major = major
    @minor = minor
  end

  def increment_minor
    @minor += 1
  end

  def increment_major
    @major += 1
    @minor = 1
  end

  def to_s
    "#{@major}.#{@minor}"
  end
end
