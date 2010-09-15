# Test cases for the WorldCat Ruby API
# Author:: Vivien Didelot 'v0n' <vivien.didelot@gmail.com>

require 'test/unit'
require 'worldcat'

# Note: I usually run test from the lib/ folder.

# Ask the API key on standard input
print "WorldCat API key: "
WCKEY = STDIN.gets.strip

class WorldCatTest < Test::Unit::TestCase
  def setup
    @client = WorldCat.new WCKEY
  end

  def test_do_request
    assert_raise WorldCat::WorldCatError do
      @client.open_search :wskey => ''
    end
  end

  def test_open_search
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

  def test_sru_search
    assert_raise WorldCat::WorldCatError do
      @client.sru_search :query => "Civil War"
    end

    # MARC XML
    reader = @client.sru_search :query => '"Civil War"', :format => :marcxml
    assert_kind_of MARC::XMLReader, reader

    records = Array.new
    reader.each do |record|
      assert_kind_of MARC::Record, record
      records.push record
    end
    assert_equal 10, records.size
    assert_equal "Americans", records.first["650"]["a"]
    assert_equal "DLC.", records.first["710"]["5"]
    assert_equal "The Civil War", records[8]["245"]["a"]

    # With SRU CQL search
    cql = 'srw.kw="civil war" and (srw.su="antietam" or srw.su="sharpsburg")'
    reader = @client.sru_search :q => cql
    assert_kind_of MARC::XMLReader, reader

    records = Array.new
    reader.each do |record|
      assert_kind_of MARC::Record, record
      records.push record
    end
    assert_equal 10, records.size
    assert_equal "Antietam, Battle of, Md., 1862.", records.first["650"]["a"]
    # Dublin Core
  end
end
