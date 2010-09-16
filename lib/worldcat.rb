# Simple WorldCat Search Ruby API
# http://oclc.org/developer/services/WCAPI
#
# Author:: Vivien Didelot 'v0n' <vivien.didelot@gmail.com>

require 'rubygems'
require 'open-uri'
require 'simple-rss'
require 'marc'
require 'rexml/document'
require 'cql_ruby'

# The WorldCat class methods use WorldCat webservices.
# Options are given as a hash, and keys may be String or Symbol with:
# * the same name than GET parameters,
# * Ruby naming convention (i.e. underscore),
# * or an alias if available.
#
# Note: aliases have priority.
#
# For a complete list of parameters, see documentation here:
# http://oclc.org/developer/documentation/worldcat-search-api/parameters

# The WorldCat class, used to interact with the WorldCat search webservices.
class WorldCat

  # A specific WorldCat error class.
  class WorldCatError < StandardError
    def initialize(details = nil)
      @details = details
    end
  end

  # The WorldCat webservices API key.
  attr_writer :api_key

  # The raw response from WorldCat.
  attr_reader :raw

  # The constructor.
  # The API key can be given here or later.
  def initialize(api_key = nil)
    @api_key = api_key
    @raw = nil
  end

  # OpenSearch method.
  #
  # Aliases:
  # * :query is an alias for :q
  # * :max is an alias for :count
  # * :citation_format is an alias for :cformat
  #
  # This method returns a SimpleRSS object. You can see the usage on:
  # http://simple-rss.rubyforge.org/
  def open_search(options)
    #TODO add other feed_tags

    # Check aliases
    options.keys.each do |k|
      case k.to_s
      when "query" then options[:q] = options.delete(k)
      when "max" then options[:count] = options.delete(k)
      when "citation_format" then options[:cformat] = options.delete(k)
      end
    end

    fetch("search/opensearch", options)
    SimpleRSS.parse @raw
    #TODO rescue SimpleRSS Error? (i.e. response too small)
  end

  # SRU Search method.
  #
  # Aliases:
  # * :q is an alias for :query
  # * :format is an alias for :record_schema
  # and its value can match "marc" or "dublin", or can be the exact value. e.g.
  #   :format => :marcxml
  # * :citation_format is an alias for :cformat
  # * :start is an alias for :start_record
  # * :count and :max are aliases for :maximum_records
  #
  # This method returns a MARC::XMLReader object. You can see the usage on:
  # http://marc.rubyforge.org/
  def sru_search(options)
    #TODO add other control_tags?

    # Check aliases
    options.keys.each do |k|
      case k.to_s
      when "q" then options[:query] = options.delete(k)
        #TODO aliases for keywords, title, author, subject to simplify the query
        # => not sure: how to write operator?
      when /(count|max)/ then options[:maximum_records] = options.delete(k)
      when "citation_format" then options[:cformat] = options.delete(k)
        #TODO alias for frbrGrouping => true|false
      when "format"
        format = options.delete(k).to_s
        options[:record_schema] = case format
                                  when /marc/ then "info:srw/schema/1/marcxml"
                                  when /dublin/ then "info:srw/schema/1/dc"
                                  else format
                                  end
      end
    end

    # Parse the CQL query. Raises a CqlException if it is not valid.
    options[:query] = CqlRuby::CqlParser.new.parse(options[:query]).to_cql

    fetch("search/sru", options, true)
    #TODO specific constructor for Dublin Core?
    marc_to_array
  end

  private

  # Helper method to convert a MARC::XMLReader in an array of records.
  # That's easier to use and better because of the bug
  # that makes the REXML reader empty after the first #each call.
  def marc_to_array
    reader = MARC::XMLReader.new(StringIO.new @raw)
    records = Array.new
    reader.each { |record| records << record }

    records
  end

  # Method to fetch the raw response from WorldCat webservices.
  # With diagnostic set to true, it will check for error from WorldCat.
  def fetch(url_comp, options, diagnostic = false)
    # Use the API key attribute or the one provided.
    options = {:wskey => @api_key}.merge options

    url = "http://www.worldcat.org/webservices/catalog/" << url_comp << "?"
    url << options.map { |k, v| "#{camelize(k)}=#{parse_value(v)}" }.join("&")

    begin
      open URI.escape(url) do |raw|
        @raw = raw.read
      end
    rescue OpenURI::HTTPError => e
      if e.message =~ /status=UNAUTHENTICATED/
        raise WorldCatError.new(e.message), "Authentication failure"
      else raise e
      end
    end

    # Check for diagnostics
    if diagnostic
      xml = REXML::Document.new @raw
      unless xml.root.elements['diagnostics'].nil?
        d = xml.root.elements['diagnostics'].elements.first
        details = d.elements["details"].text
        message = d.elements["message"].text

        raise WorldCatError.new(details), message
      end
    end
  end

  # Helper function to camelize a string or symbol
  # to match WorldCat services parameters.
  def camelize(key)
    key.to_s.gsub(/_(\w)/) { |m| m.sub('_', '').capitalize }
  end

  # Helper function to parse a array, number or string
  # to match WorldCat services parameters.
  def parse_value(value)
    value.is_a?(Array) ? value.join(',') : value.to_s
  end
end
