# Simple WorldCat Search Ruby API
# http://oclc.org/developer/services/WCAPI
#
# Author:: Vivien Didelot 'v0n' <vivien.didelot@gmail.com>

require 'rubygems'       # needed by simple-rss
require 'open-uri'       # used to fetch responses
require 'simple-rss'     # used for Atom and RSS format
require 'marc'           # used for MARC records
require 'rexml/document' # used for many XML purposes
require 'cql_ruby'       # used to parse SRU CQL query
require 'json'           # used for JSON format

# The WorldCat class methods use WorldCat webservices.
# Options are given as a hash and Symbol keys may be:
# * the same name than GET parameters,
# * Ruby naming convention (i.e. underscore),
# * or aliases if available.
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
      case k
      when :query then options[:q] = options.delete(k)
      when :max then options[:count] = options.delete(k)
      when :citation_format then options[:cformat] = options.delete(k)
      end
    end

    fetch("search/opensearch", options)
    #TODO diagnostic
    SimpleRSS.parse @raw
    #TODO rescue SimpleRSS Error? (i.e. response too small)
  end

  # SRU search method.
  #
  # aliases:
  # * :q is an alias for :query
  # * :format is an alias for :record_schema
  # and its value can match "marc" or "dublin", or can be the exact value. e.g.
  #   :format => :marcxml
  # * :citation_format is an alias for :cformat
  # * :start is an alias for :start_record
  # * :count and :max are aliases for :maximum_records
  #
  # The CQL query will be parsed and can raise an exception if it is not valid.
  #
  # this method returns an array of MARC::Record objects for marc format
  # (you can see the usage on http://marc.rubyforge.org),
  # or a REXML::Document for Dublin Core format.
  def sru_search(options)
    #TODO add other control_tags?

    # Check aliases
    options.keys.each do |k|
      case k
      when :q then options[:query] = options.delete(k)
      when :count, :max then options[:maximum_records] = options.delete(k)
      when :start then options[:start_record] = options.delete(k)
      when :citation_format then options[:cformat] = options.delete(k)
      when :format
        format = options.delete(k).to_s
        format = "info:srw/schema/1/marcxml" if format =~ /marc/
        format = "info:srw/schema/1/dc" if format =~ /dublin/
        options[:record_schema] = format
      end
    end

    # Parse the CQL query. Raises a CqlException if it is not valid.
    options[:query] = CqlRuby::CqlParser.new.parse(options[:query]).to_cql
    fetch("search/sru", options, true)

    format = options[:record_schema]
    if format.nil? || format == "info:srw/schema/1/marcxml"
      marc_to_array
    else
      REXML::Document.new @raw
    end
  end

  # Library locations method.
  #
  # aliases:
  # * :start is an alias for :start_library
  # * :count and :max are aliases for :maximum_libraries
  # * :latitude is an alias for :lat
  # * :longitude is an alias for :lon
  # * libtype can be given as text value as well. e.g.:
  #   :libtype => :academic
  # * record identifier should be given as type => id. e.g.:
  #   :isbn => "014330223X"
  #
  # this method returns a REXML::Document for XML format,
  # or a Hash for JSON format.
  def library_locations(options)
    url_comp = "content/libraries/"

    # Check aliases
    options.keys.each do |k|
      case k
      when :count, :max then options[:maximum_libraries] = options.delete(k)
      when :start then options[:start_library] = options.delete(k)
      when :latitude then options[:lat] = options.delete(k)
      when :longitude then options[:lon] = options.delete(k)
      when :format then options.delete(k) if options[k].to_s == "xml"
      when :libtype
        libtype = options[k].to_s
        options[k] = 1 if libtype =~ "academic"
        options[k] = 2 if libtype =~ "public"
        options[k] = 3 if libtype =~ "government"
        options[k] = 4 if libtype =~ "other"
      when :oclc then url_comp << options[k].to_s
      when :isbn then url_comp << "isbn/" << options[k].to_s
      when :issn then url_comp << "issn/" << options[k].to_s
      when :sn then url_comp << "sn/" << options[k].to_s
      end
    end

    if options.has_key? :format
      fetch(url_comp, options, false)
      response = JSON.parse(@raw)
      if response.has_key? "diagnostic"
        details = response["diagnostic"].first["details"]
        message = response["diagnostic"].first["message"]
        raise WorldCatError.new(details), message
      end
    else
      fetch(url_comp, options, true)
      response = REXML::Document.new(@raw)
    end

    response
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
      d = xml.elements['diagnostics']
      d = xml.root.elements['diagnostics'] if d.nil?
      unless d.nil?
        d = d.elements.first
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
