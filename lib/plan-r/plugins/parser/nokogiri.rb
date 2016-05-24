#!/usr/bin/env ruby
# :title: PlanR::Plugins::Parser::Nokogiri
=begin rdoc
Built-in HTML and XML parser
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org> 
=end

require 'tg/plugin'
require 'plan-r/document'

require 'nokogiri'

# TODO: For XML, download DTD during mirror

module PlanR
  module Plugins
    module Parser

=begin rdoc
Nokogiri-based plugin
=end
      class Nokogiri
        extend TG::Plugin
        name 'Nokogiri Parser'
        author 'dev@thoughtgang.org'
        version '1.0'
        description 'Use the Nokogiri module to parse HTML and XML files'
        help 'This plugin can mirror remote HTML documents and parse HTML and
XML documents.
Note that a Data Source plugin is required for document retrieval when
mirroring.'

        # ---------------------------------------------------------------------
        # PARSE
=begin rdoc
Extract plaintext from a node and all of its children
=end
        def extract_plaintext(node, doc)
          return if ! node
          if node.text?
            doc.add_text_block(node.text.strip) if ! (node.text.strip.empty?)
          end
          # TODO: iterate over node.attr ?
          node.children.each { |child| extract_plaintext(child, doc) }
        end

=begin rdoc
Extract plaintext, content-type from an XML document.
=end
        def parse_xml(pdoc, data)
          # TODO: DTD, etc
          src = ::Nokogiri::XML(data)
          extract_plaintext(src.root, pdoc)
          pdoc.content_type="application/xml; charset=#{src.encoding}"
        end

=begin rdoc
Extract plaintext, CSS, JS, Images, external links, and metadata from 
an HTML document.
=end
        def parse_html(pdoc, data)
          src = ::Nokogiri::HTML(data)
          pdoc.properties[:title] = src.title
          extract_plaintext(src.root, pdoc)

          # css, js, images
          src.xpath('//link[@rel="stylesheet"]').each do |t|
            pdoc.add_ext_ref(t[:href], PlanR::ParsedDocument::REF_STYLE)
          end

          src.xpath('//script[@src]').each do |t|
            pdoc.add_ext_ref(t[:src], PlanR::ParsedDocument::REF_SCRIPT)
          end

          src.xpath('//img[@src]').each do |t|
            pdoc.add_ext_ref(t[:src], PlanR::ParsedDocument::REF_IMAGE)
          end

          # links
          src.xpath('//a[@href]').each do |t|
            next if (t[:href].start_with? '#')
            next if (t[:href].start_with? 'mailto:')
            pdoc.add_ext_ref(t[:href], PlanR::ParsedDocument::REF_DOC)
          end

          # metadata
          meta = {}
          src.xpath('//meta').each do |t|
            last_name = name = value = nil
            t.attributes.each do |key, attr|
              if attr.name == 'content'
                value = attr.value
              elsif attr.name == 'name'
                name = attr.value
              else
                last_name = attr.value
              end
            end
            name = last_name if not name
            meta[name.downcase] = value if name && value
          end
          meta.fetch('keywords', '').split(',').each do |keyword|
            pdoc.keywords << keyword
          end
          pdoc.properties[:content_type] = meta.fetch('content-type', '')
          pdoc.properties[:description] = meta.fetch('description', '')
        end

=begin rdoc
Use Nokogiri to generate a ParsedDocument for the source document
=end
        def parse(doc)
          mime = doc.properties[:mime_type]
          pdoc = PlanR::ParsedDocument.new(name, doc)
          begin
            ['text/html', 'application/xhtml+xml'].include?(mime) ?
                                              parse_html(pdoc, doc.contents) :
                                              parse_xml(pdoc, doc.contents)
          rescue Exception => e
            $stderr.puts 'Nokigiri :parse_doc Exception: ' + e.message
            $stderr.puts e.backtrace[0..5].join("\n")
          end
          pdoc
        end
        spec :parse_doc, :parse, 60 do |doc|
          ['application/xml', 'text/html', 'application/xhtml+xml'
          ].include?(doc.properties[:mime_type]) ? 75 : 0
        end

        # ---------------------------------------------------------------------
        # MIRROR
=begin rdoc
Return str if it is an absolute URL (i.e. it begins with protocol handler);
otherwise, return uri.dirname + url.
=end
        def absolute_url_for(uri, str)
          # TODO: use URI.parse() for better handling?
          return str if str =~ /^[|[:alpha:]]+:\/\//
          File.join(((uri.path.empty?) ? uri.to_s : File.dirname(uri.to_s)), 
                     str)
        end

=begin rdoc
Return a local URL for files in 'url' based in 'dir'.

The URL is cleaned according to the following rules:
  Remove protocol from beginning of URL.
  Remove all . and .. entries from URL.
  Replace all non-cstr (plus -,., and /)  characters with '_'.
=end
        def path_for_url(dir, subdir, url)
          path = url.gsub(/^[|[:alpha:]]+:\/\//, '')
          path.gsub!(/^[.\/]+/, '')
          path.gsub!(/[^-_.\/[:alnum:]]/, '_')
          File.join(dir, subdir, path)
        end

=begin rdoc
Generate a path for use in an href tag. 
This means localizing to "../.CONTENT.rsrc/".
=end
        def ref_path(dir, subdir, path)
          # this stuff is overkill, and doesn't work anyways:
          #depth = dir.split(File::SEPARATOR).reject{ |d| d.empty? }.count
          #parent_dirs = Array.new(depth, '..')
          File.join('..', ContentRepo::ResourceNode::PATHNAME, path )
        end

=begin rdoc
Fetch resource contents using data_source Plugin.
=end
        def download_resource(loader, src_url)
          # play nice with remote web servers
          sleep(rand / 100) if src_url =~ /^[[:alpha:]]+:/
          begin
            loader.spec_invoke(:data_source, src_url, nil)
          rescue Exception => e
            # FIXME: log
            $stderr.puts "[NOKOGIRI] Cannot download resource : #{e.message}"
            $stderr.puts e.backtrace[0,2].join("\n")
            nil
          end
        end

=begin rdoc
Mirror a remote reource locally.
This downloads the resource in a tag using the provided plugin, saves it to 
the specified directory, then updates the tag t point to the downloaded file.
=end
        def localize_resource(tag, sym, loader, uri, dir, subdir, h, props)
          rel_url = tag[sym]
          src_url = absolute_url_for(uri, rel_url)

          buf = download_resource(loader, src_url)
          return if (! buf) or (buf.empty?)

          path = path_for_url(dir, subdir, rel_url)
          # Fix for super-long filenames. wikipedia, for example, has these
          if path.length > 256
            path = path_for_url(dir, subdir, rel_url[0,256])
          end

          local_ref = ref_path(dir, subdir, path)

          # localize tag ref
          tag[sym.to_s] = local_ref

          # store remote contents in Hash under path
          h[path] = buf
          # TODO: mime-type?
          props[path] = { :origin => src_url, :relative_path => local_ref }
        end

        def mirror_stylesheets(src, loader, uri, base_path, h)
          src.xpath('//link[@rel="stylesheet"]').each do |tag|
            localize_resource(tag, :href, loader, uri, base_path, 'styles',
                              h[:resources], h[:properties])
          end
        end

        def mirror_scripts(src, loader, uri, base_path, h)
          src.xpath('//script[@src]').each do |tag|
            localize_resource(tag, :src, loader, uri, base_path, 'script', 
                              h[:resources], h[:properties])
          end
        end

        def mirror_images(src, loader, uri, base_path, h)
          src.xpath('//img[@src]').each do |tag|
            localize_resource(tag, :src, loader, uri, base_path, 'images', 
                              h[:resources], h[:properties])
          end
        end

=begin rdoc
Use Nokogiri to parse an HTML document, download its resources (images,
stylesheets, javascript), and rewrite resource references to refer to the
repo ResourceTree.
=end
        def mirror_html(doc, buf, loader)
          h = { :contents => buf, :resources => {}, :properties => {} }
          return h if ! (loader && (loader.spec_supported? :data_source))
          return h if ! doc.origin

          begin
            src = ::Nokogiri::HTML(buf.empty? ? File.read(doc) : buf)
            return if ! src

            base_path = doc.path
            uri = URI.parse(doc.origin)

            # External Stylesheets
            mirror_stylesheets(src, loader, uri, base_path, h)
            mirror_scripts(src, loader, uri, base_path, h)
            mirror_images(src, loader, uri, base_path, h)

            # Remove all basepath tags
            src.xpath('//base').each { |tag| tag.remove }

          rescue Exception => e
            $stderr.puts 'Nokigiri :mirror_doc Exception: ' + e.message
            $stderr.puts e.backtrace[0..5].join("\n")
          end

          h[:contents] = src.to_html
          # FIXME: fill properties
          h[:properties][:contents] = {}

          h
        end
        spec :mirror_doc, :mirror_html, 60 do |doc, buf, loader|
          # :data_source plugin is required
          next 0 if ! (loader && (loader.spec_supported? :data_source))
          ['text/html', 'application/xhtml+xml'
          ].include?(doc.properties[:mime_type]) ? 75 : 0
        end
      end

    end
  end
end
