require 'morph'
require 'hpricot'
require 'open-uri'

module LegislationUK

  module Title
    def title
      contents_title.is_a?(String) ? contents_title.strip : contents_title.title.strip
    end
  end

  module ItemNumber
    def number
      contents_number
    end
  end

  module LegislationUri
    def legislation_uri
      document_uri
    end
  end

  class Legislation
    include Morph
    include LegislationUri

    def self.open_uri uri
      open(uri).read
    end

    def title
      metadata.title
    end

    def parts
      if contents
        if contents.respond_to?(:contents_parts)
          contents.contents_parts
        elsif contents.respond_to?(:contents_part)
          [contents.contents_part]
        else
          []
        end
      else
        []
      end
    end

    def statutelaw_uri
      if legislation_uri[%r|http://www.legislation.gov.uk/(.+)/(\d\d\d\d)/(\d+)|]
        type = $1
        year = $2
        chapter = $3
        "http://www.statutelaw.gov.uk/documents/#{year}/#{chapter}/#{type}/c#{chapter}"
      else
        nil
      end
    end

    def opsi_uri
      unless @opsi_uri
        search_url = "http://search.opsi.gov.uk/search?q=#{URI.escape(title)}&output=xml_no_dtd&client=opsisearch_semaphore&site=opsi_collection"
        begin
          doc = Hpricot.XML Legislation.open_uri(search_url)
          url = nil

          (doc/'R/T').each do |result|
            unless url
              term = result.inner_text.gsub(/<[^>]+>/,'').strip
              url = result.at('../U/text()').to_s if(title == term || term.starts_with?(title))
            end
          end

          @opsi_uri = url
        rescue Exception => e
          puts 'error retrieving: ' + search_url
          puts e.class.name
          puts e.to_s
        end
      end
      @opsi_uri
    end
  end

  class ContentsPart
    include Morph
    include Title
    include ItemNumber
    include LegislationUri

    def blocks
      if respond_to?(:contents_pblocks)
        contents_pblocks ? contents_pblocks : []
      else
        []
      end
    end

    def sections
      if blocks.empty?
        contents_items ? contents_items : []
      else
        blocks.collect(&:sections).flatten
      end
    end
  end

  class ContentsPblock
    include Morph
    include Title
    include LegislationUri

    def sections
      contents_items ? contents_items : []
    end
  end

  class ContentsItem
    include Morph
    include Title
    include ItemNumber
    include LegislationUri
  end
end


# See README for usage documentation.
module Legislation
  module UK
    VERSION = "0.0.2"

    def self.open_uri uri
      open(uri).read
    end

    def self.to_object xml
      xml.gsub!(' Type=',' TheType=')
      xml.gsub!('dc:type','dc:the_type')
      hash = Hash.from_xml(xml)
      namespace = LegislationUK
      Morph.from_hash(hash, namespace)
    end

    def self.find title, number=nil
      begin
        number_part = number ? "&number=#{number}" : ''
        search_url = "http://www.legislation.gov.uk/id?title=#{URI.escape(title)}#{number_part}"
        xml = Legislation::UK.open_uri(search_url)
        to_object(xml)
      rescue Exception => e
        puts 'error retrieving: ' + search_url
        puts e.class.name
        puts e.to_s
        raise e
        nil
      end
    end

  end
end
