# Simple WorldCat Search Ruby API
# http://oclc.org/developer/services/WCAPI
#
# Author:: Vivien Didelot 'v0n' <vivien.didelot@gmail.com>

require 'rubygems'
require 'open-uri'
require 'simple-rss'
require 'marc'
require 'rexml/document'

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

class WorldCat
  class WorldCatError < StandardError
    def initialize(details)
      @details = details
    end
  end

  attr_writer :api_key
  attr_reader :raw

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

    do_request("search/opensearch", options)
    SimpleRSS.parse @raw
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
  def sru_search(options)
    #TODO add other control_tags?

    # Check aliases
    options.keys.each do |k|
      case k.to_s
      when "q" then options[:query] = options.delete(k)
        #TODO aliases for keywords, title, author, subject to simplify the query
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

    do_request("search/sru", options, true)

    #TODO specific constructor for Dublin Core?
    MARC::XMLReader.new(StringIO.new @raw)
  end

  private

  def do_request(url_comp, options, diagnostic = false)
    # Use the API key attribute or the one provided.
    options = {:wskey => @api_key}.merge options

    url = "http://www.worldcat.org/webservices/catalog/" << url_comp << "?"
    url << options.map { |k, v| "#{camelize(k)}=#{parse_value(v)}" }.join("&")

    begin
      open URI.escape(url) do |raw|
        @raw = raw.read
      end
    rescue OpenURI::HTTPError => e
      raise WorldCatError, e.message
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

  def camelize(key)
    key.to_s.gsub(/_(\w)/) { |m| m.sub('_', '').capitalize }
  end

  def parse_value(value)
    value.is_a?(Array) ? value.join(',') : value.to_s
  end
end
