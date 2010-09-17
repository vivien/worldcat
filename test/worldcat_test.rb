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
    records = @client.sru_search :query => '"Civil War"',
      :sort_keys => ['Date','' ,0],
      :format => :marcxml
    assert_kind_of Array, records
    records.each { |r| assert_kind_of MARC::Record, r }
    assert_equal 10, records.size
    assert_equal "Touched with fire :", records[8]["245"]["a"]

    cql = 'srw.kw="civil war" and (srw.su="antietam" or srw.su="sharpsburg")'
    records = @client.sru_search :q => cql
    assert_kind_of Array, records
    records.each { |r| assert_kind_of MARC::Record, r }
    assert_equal 10, records.size
    assert_equal "Antietam, Battle of, Md., 1862.", records.first["650"]["a"]

    # Dublin Core
    dublin = @client.sru_search :q => cql, :format => "dublincore"
    assert_kind_of REXML::Document, dublin
  end

  def test_library_locations
    assert_raise WorldCat::WorldCatError do
      @client.library_locations :location => "XXXX", :format => "xml"
    end

    assert_raise WorldCat::WorldCatError do
      @client.library_locations :location => "XXXX", :format => "json"
    end

    xml = @client.library_locations :isbn => "014330223X", :location => 2220
    assert_kind_of REXML::Document, xml
    #TODO add verification

    json = @client.library_locations :isbn => "014330223X", :location => 2220, :format => "json"
    assert_kind_of Hash, json
    #TODO add verification
  end

  def test_single_record
    assert_raise WorldCat::WorldCatError do
      @client.single_record :oclc => "0000"
    end

    record = @client.single_record :isbn => "0596000278"
    assert_kind_of MARC::Record, record
    assert_equal "Programming Perl /", record["245"]["a"]
  end

  def test_library_catalog_url
    assert_raise WorldCat::WorldCatError do
      @client.library_catalog_url :oclcsymbol => "XXXX"
    end

    assert_raise WorldCat::WorldCatError do
      @client.library_catalog_url :isbn => "0000", :oclcsymbol => "OSU"
    end

    xml = @client.library_catalog_url :isbn => "0026071800", :oclcsymbol => "OSU"
    assert_kind_of REXML::Document, xml
    assert_equal "Ohio State University Libraries", xml.root.elements.first.elements["physicalLocation"].text

    xml = @client.library_catalog_url :oclc => "15550774", :oclcsymbol => ["OSU", "STF"]
    assert_kind_of REXML::Document, xml
    assert_equal "Ohio State University Libraries", xml.root.elements.first.elements["physicalLocation"].text
    assert_equal "Stanford University Library", xml.root.elements[2].elements["physicalLocation"].text
  end

  def test_formatted_citations
    assert_raise WorldCat::WorldCatError do
      @client.formatted_citations :oclc => "0000"
    end

    assert_raise WorldCat::WorldCatError do
      @client.formatted_citations :oclc => "15550774", :citation_format => :xxxx
    end

    citation = @client.formatted_citations :oclc => "15550774"
    assert_kind_of String, citation
    assert_equal '<p class="citation_style_MLA">McPherson, James M. <i>Battle Cry of Freedom: The Civil War Era</i>. The Oxford history of the United States, v. 6. New York: Oxford University Press, 1988. </p>', citation

    citation = @client.formatted_citations :oclc => "15550774", :cformat => "chicago"
    assert_kind_of String, citation
    assert_match /CHICAGO/, citation
  end
end
