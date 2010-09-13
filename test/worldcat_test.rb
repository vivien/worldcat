# Test cases for the WorldCat Ruby API
# Author:: Vivien Didelot 'v0n' <vivien.didelot@gmail.com>

require 'test/unit'
require 'worldcat'

# I usually run test from the lib/ folder.

class WorldCatTest < Test::Unit::TestCase
  def setup
    @client = WorldCat.new

    # Ask the API key on standard input
    print "WorldCat API key: "
    @client.api_key = STDIN.gets.strip
  end

  def do_request_test
    assert_raise WorldCatError do
      @client.open_search :wskey => ''
    end
  end

  def open_search_test
    # A search for civil war, returning a result with the default Atom format, starting position, and count
    atom = @client.open_search :query => "Civil War"

    assert_kind_of SimpleRSS, atom
    assert_equal 10, atom.entries.size
    assert_equal "OCLC Worldcat Search: Civil War", atom.feed.title
    assert_equal "Hemingway, Ernest, 1899-1961.", atom.entries.first.author

    # A search for civil war, returning a result in the RSS format, starting at position 6, with a count of 5 records
    rss = @client.open_search :q => "Civil War", :format => "rss", :start => 6, :count => 5

    assert_kind_of SimpleRSS, rss
    assert_equal 5, rss.items.size
    assert_equal "OCLC Worldcat Search: Civil War", rss.channel.title
    assert_equal "Cashin, Joan E.", rss.items.last.author

    # A search for civil war, returning a result in the Atom format, including an MLA-formatted citation for each record
    atom = @client.open_search :q => "Civil War", :format => "atom", :cformat => "mla"
    assert_kind_of SimpleRSS, atom
    assert_equal 10, atom.entries.size
    assert_equal "OCLC Worldcat Search: Civil War", atom.feed.title
    assert_equal "&lt;p class=\"citation_style_MLA\"&gt;Hemingway, Ernest. &lt;i&gt;For Whom the Bell Tolls&lt;/i&gt;. New York: Scribner, 1940. Print. &lt;/p&gt;", atom.entries.first.content
  end

  def sru_search_test
    #marc = @client.sru_search :q => ""
  end
end
