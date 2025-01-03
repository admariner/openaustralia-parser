# frozen_string_literal: true

# Handle all our silly name parsing needs
class Name
  attr_reader :title, :first, :middle, :initials, :last, :post_title

  def initialize(params)
    # First normalize the unicode.
    params.map { |key, value| [key, value&.unicode_normalize(:nfkc)] }

    @title = params[:title] || ""
    @first = (Name.capitalize_name(params[:first]) if params[:first]) || ""
    @middle = (Name.capitalize_each_name(params[:middle]) if params[:middle]) || ""
    @initials = params[:initials]&.upcase || ""
    @post_title = params[:post_title]&.upcase || ""
    @last = (Name.capitalize_each_name(params[:last]) if params[:last]) || ""
    invalid_keys = params.keys - %i[title first middle initials last post_title]
    raise "Invalid keys #{invalid_keys} used" unless invalid_keys.empty?
  end

  def self.remove_text_in_brackets(text)
    open = text.index("(")
    if open
      close = text.index(")", open)
      text = text[0..open - 1] + text[close + 1..] if close
    end

    # Remove extra spaces
    text.squeeze(" ")
  end

  # Check if two names are actually one name (in other words a double-barreled name that hasn't been hyphenated)
  # We can only handle this by having specific instances to check for
  def self.double_barreled_name?(name1, name2)
    n1 = name1.downcase
    n2 = name2.downcase
    (n1 == "stott" && n2 == "despoja") ||
      (n1 == "van" && n2 == "manen") ||
      (n1 == "di" && n2 == "natale") ||
      (n1 == "nampijinpa" && n2 == "price")
  end

  def self.last_title_first(text)
    # First normalize the unicode. Using this form of normalize so that non-breaking spaces get turned into 'normal' spaces
    text = text.unicode_normalize(:nfkc)
    # Do the following before the split so we can handle things like "(foo bar)"
    text = remove_text_in_brackets(text)
    names = text.delete(",").split
    if (names.size >= 2) && double_barreled_name?(names[0], names[1])
      last = names[0..1].join(" ")
      names.shift
      names.shift
    # Check for hyphenated last names
    elsif names[1] == "-"
      last = names.shift(3).join
    else
      last = names.shift
    end
    title = Name.extract_title_at_start(names)
    # Check for hypenated first name
    if names[1] == "-"
      first = names.shift(3).join
    elsif names.size >= 1
      # First name could be in the form of initials. So, check for this
      if initials(names[0])
        # Allow several initials separated by spaces
        initials = +""
        initials << initials(names.shift) while names.size >= 1 && initials(names[0])
      else
        first = names.shift
      end
    end
    post_title = extract_post_title_at_end(names)
    middle = names[0..].join(" ")
    Name.new(title: title, initials: initials, last: last, first: first, middle: middle, post_title: post_title)
  end

  # Extract a post title from the end if one is available
  def self.post_title(names)
    valid_post_titles = %w[AM SC AO MBE QC KC OBE KSJ JP MP AC RFD OAM MC CSC]
    names.pop if valid_post_titles.include?(names.last)
  end

  # Returns initials if the name could be a set of initials
  def self.initials(name)
    # If only one or two letters assume that these are initials
    # HACK: Added specific handling for initials DJC, DGH
    if initials_with_fullstops(name)
      initials_with_fullstops(name)
    # Heuristic: If word is all caps we'll assume that these are initials
    # HACK: Unless it's "DAVID", which is how SMITH, DAVID is represented.
    elsif name == "DAVID"
      nil
    # HACK: unless it is "-", which could be part of a hyphenated name in specific case
    elsif ((name.upcase == name) && name != "-") || (name != "Ed" && name != "Jo" && name != "-" && name.size <= 2) || name == "DJC" || name == "DGH"
      name
    end
  end

  # Returns true if the name could be a set of initials with full stops in them (e.g. "A.B.")
  def self.initials_with_fullstops(name)
    # Heuristic: If word has any fullstops in it we'll assume that these are initials
    # This allows a degree of flexibility, such as allowing "A.B.", "A.B..", "A.B.C", etc...
    name.delete(".") if name.include?(".")
  end

  def self.title_first_last(text)
    # First normalize the unicode. Using this form of normalize so that non-breaking spaces get turned into 'normal' spaces
    text = text.unicode_normalize(:nfkc)
    names = text.delete(",").split
    title = Name.extract_title_at_start(names)
    if names.size == 1
      last = names[0]
    elsif (names.size == 2) && double_barreled_name?(names[0], names[1])
      last = names[0..1].join(" ")
      names.shift
      names.shift
    elsif names.size >= 2
      if initials(names[0])
        initials = initials(names.shift)
      else
        first = names.shift
      end
      post_title = extract_post_title_at_end(names)
      if (names.size >= 2) && double_barreled_name?(names[-2], names[-1])
        last = names[-2..].join(" ")
        names.pop
      else
        last = names[-1]
      end
      names.pop
      middle = names[0..].join(" ")
    end
    Name.new(title: title, last: last, first: first, middle: middle, initials: initials, post_title: post_title)
  end

  def first_initial
    if first_initial?
      @initials[0..0]
    else
      @first[0..0]
    end
  end

  def middle_initials
    if middle_initials?
      @initials[1..]
    else
      @middle.split.map { |n| n[0..0] }.join
    end
  end

  def real_initials
    # If only one or two letters assume that these are initials
    # HACK: Added specific handling for initials DJC, DGH
    if !@initials.nil? && !@initials.empty?
      @initials
    elsif !@first.nil?
      if @first.upcase == @first || (@first != "Ed" && @first.size <= 2) || @first == "DJC" || @first == "DGH"
        @first
      else
        p_initials = first_initial
        p_initials = "#{p_initials}#{@middle.split.map { |n| n[0..0] }.join}" unless @middle.nil?
        p_initials
      end
    end
  end

  def informal_name
    raise "No last name" unless last?

    "#{@first} #{@last}"
  end

  def full_name
    t = ""
    t += "#{title} " if title?
    t += "#{first} " if first?
    t += "#{middle} " if middle?
    t += last.to_s
    t += ", #{post_title}" if post_title?
    t
  end

  def title?
    @title != ""
  end

  def first?
    @first != ""
  end

  def middle?
    @middle != ""
  end

  def first_initial?
    !@initials.empty?
  end

  def middle_initials?
    @initials.size > 1
  end

  def last?
    @last != ""
  end

  def post_title?
    @post_title != ""
  end

  def first_matches?(name)
    if !first? || !name.first?
      # Check here if one name has initials and no first name and the other has a first name
      if (first_initial? && name.first?) || (first? && name.first_initial?)
        first_initial == name.first_initial
      else
        true
      end
    elsif first.size < name.first.size
      name.first_matches?(self)
    else
      first == name.first
    end
  end

  def middle_matches?(name)
    if !middle? || !name.middle?
      if (middle_initials? && name.middle?) || (middle? && name.middle_initials?)
        middle_initials == name.middle_initials[0..middle_initials.length - 1]
      else
        true
      end
    else
      @middle == name.middle
    end
  end

  # Names don't have to be identical to match but rather the parts of the name
  # that exist in both names have to match
  def matches?(name)
    # Both names need to have a last name to match
    return false unless last? && name.last?

    (!title? || !name.title? || @title == name.title) &&
      first_matches?(name) &&
      middle_matches?(name) &&
      (!last?       || !name.last?       || @last       == name.last) &&
      (!post_title? || !name.post_title? || @post_title == name.post_title)
  end

  def ==(other)
    @title == other.title && @first == other.first &&
      @middle == other.middle && @initials == other.initials && @last == other.last && @post_title == other.post_title
  end

  def self.extract_title_at_start(names)
    titles = []
    while (title = Name.title(names))
      titles << title
    end
    titles.join(" ")
  end

  def self.extract_post_title_at_end(names)
    post_titles = []
    while (post_title = Name.post_title(names))
      post_titles.unshift(post_title)
    end
    post_titles.join(" ")
  end

  def self.matches_hon?(name)
    name.downcase == "hon." || name.downcase == "hon" || name.downcase == "honourable" || name.downcase == "honourable."
  end

  # Extract a title at the beginning of the list of names if available and shift
  def self.title(names)
    if names.size >= 3 && names[0].downcase == "the" && names[1].downcase == "rt" && matches_hon?(names[2])
      names.shift
      names.shift
      names.shift
      "the Rt Hon."
    elsif names.size >= 2 && names[0].downcase == "the" && matches_hon?(names[1])
      names.shift
      names.shift
      "the Hon."
    elsif names.size >= 1 && matches_hon?(names[0])
      names.shift
      "Hon."
    elsif names.size >= 1
      title = names[0]
      if ["Dr", "Dr.", "Mr", "Mrs", "Ms", "Miss", "Senator", "Sen", "Lady"].include?(title)
        names.shift
        title
      end
    end
  end

  # Capitalise a name using special rules
  def self.capitalize_name(name)
    # Simple capitlisation
    name = name.capitalize
    # Replace a unicode character
    name = name.capitalize.gsub("\342\200\231", "'")
    # Exceptions to capitalisation rule
    name = name[0..1] + name[2..].capitalize if name[0..1] == "O'" || name[0..1] == "Mc" || name[0..1] == "D'"
    # If name is hyphenated capitalise each side on its own
    # TODO: Fix 'activesupport' gem so that multibyte chars properly pass through include?
    # Cast to normal string for include? necessary because of bug in activesupport multibyte chars
    name = name.split("-").map { |n| capitalize_name(n) }.join("-") if name.to_s.include?("-")
    name
  end

  def self.capitalize_each_name(name)
    name.split.map { |t| Name.capitalize_name(t) }.join(" ")
  end
end
