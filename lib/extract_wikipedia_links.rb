# frozen_string_literal: true

require "English"

def extract_all_representative_wikipedia_links(people, agent)
  links = {}
  # ["1980", "1983", "1984", "1987", "1990", "1993", "1996", "1998", "2001", "2004", "2007", "2010"].each_cons(2) do |pair|
  # Only going to get wikipedia links going back to 2004 for the time being
  %w[2004 2007 2010].each_cons(2) do |pair|
    puts "Analysing years #{pair[0]}-#{pair[1]}"
    url = "http://en.wikipedia.org/wiki/Members_of_the_Australian_House_of_Representatives%2C_#{pair[0]}-#{pair[1]}"
    extract_links_from_wikipedia(agent.get(url).parser, people, links)
  end
  links
end

def extract_all_senator_wikipedia_links(people, agent)
  links = {}
  url = "http://en.wikipedia.org/wiki/Members_of_the_Australian_Senate%2C_2005-2008"
  extract_links_from_wikipedia(agent.get(url).parser, people, links)
  links
end

# Check that there is an OpenAustralia link on the Wikipedia page. If not, display a warning
def check_wikipedia_page(url, agent)
  if url =~ %r{^http://en.wikipedia.org/wiki/(.*)$}
    title = $LAST_MATCH_INFO[1]
    edit_url = "http://en.wikipedia.org/w/index.php?title=#{title}&action=edit"
    text = agent.get(edit_url).parser.to_s
    puts "WARNING: No OpenAustralia link on #{url}" unless text =~ /\{\{OpenAustralia(\|.*)?\}\}/
  else
    puts "WARNING: Unexpected form of url: #{url}"
  end
end

def extract_links_from_wikipedia(doc, people, links)
  doc.search("//table").first.search("tr").each do |row|
    link = row.search("td a")[0]
    next unless link

    name = Name.title_first_last(link.inner_html)
    person = people.find_person_by_name(name)
    if person
      raise "Unexpected link format" unless link.get_attribute("href").match(%r{^/wiki/(.*)$})

      title = $LAST_MATCH_INFO[1]
      url = "http://en.wikipedia.org/wiki/#{title}"
      if links.key?(person.id) && links[person.id] != url
        puts "WARNING: URL for #{name.full_name} has multiple different values"
      else
        links[person.id] = url
      end
    else
      puts "WARNING: Could not find person with name #{name.full_name}"
    end
  end
  links
end
