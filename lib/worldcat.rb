require 'rubygems'
require 'open-uri'
require 'simple-rss'
require 'marc'

class WorldCat
  class WorldCatError < StandardError; end

  attr_writer :api_key
  attr_reader :raw

  def initialize(api_key = nil)
    @api_key = api_key
    @raw = nil
  end

  def open_search(options)
    #TODO add other feed_tags

    # Rename :query key to :q if it exists.
    options[:q] = options.delete(:query) if options.has_key? :query

    do_request("search/opensearch", options)

    return SimpleRSS.parse @raw
  end

  def sru_search(options, format = "marcxml")
    raise NotImplementedError

    # Rename :query key to :q if it exists.
    options[:q] = options.delete(:query) if options.has_key? :query
    options[:format] = format unless options.has_key? :format

    case options[:format]
    when "marcxml"
      raise(NotImplementedError, "RSS format not available yet")
    when "dublin"
      raise(NotImplementedError, "Atom format not available yet")
    else raise(ArgumentError, "format #{format} invalid")
    end

    do_request("search/sru", options)
  end

  private

  def do_request(url_comp, options)
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
  end

  def camelize(key)
    key.to_s.gsub(/_(\w)/) { |m| m.sub('_', '').capitalize }
  end

  def parse_value(value)
    value.is_a?(Array) ? value.join(',') : value.to_s
  end
end
