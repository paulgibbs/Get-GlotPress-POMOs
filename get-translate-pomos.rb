#!/usr/bin/env ruby
require 'rubygems'
require 'hpricot'
require 'open-uri'
require 'net/http'

=begin
Downloads .mo and .pot files from completed translations of a specific project on translate.wordpress.org.


Copyright (c) 2012 Paul Gibbs

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=end

# If required parameters are missing, bail out
if ARGV[0].nil? or ARGV[1].nil?
	puts 'Usage: get-translate-pomos.rb PROJECT VERSION'
	puts "\tPROJECT: URL slug for a project listed at http://translate.wordpress.org/projects/. e.g. buddypress"
	puts "\tVERSION: A sub-project, or version, of the PROJECT. e.g. 1.6.x"
	puts ''
	abort
end

puts "Finding translations for #{ARGV[0]} #{ARGV[1]}..."
translations = []

# Load the appropriate project page
begin
	doc = Hpricot( open( "https://translate.wordpress.org/projects/#{ARGV[0]}/#{ARGV[1]}" ).read )
rescue => error
	abort( "An error occured when trying to load https://translate.wordpress.org/projects/#{ARGV[0]}/#{ARGV[1]}: #{error}" )
end

# Iterate through each table row
doc.search( '.translation-sets tbody tr' ).each do |row|
	base_url   = row.search( 'td strong a' ).first[:href]
	completion = row.search( 'td.percent'  ).inner_html.gsub( /\n/, '' )
	lang_code  = base_url.split( '/' ).fetch( -2 ).gsub( /[^aA0-zZ9.\-]/, '_' );
	language   = row.search( 'td strong a' ).inner_html.gsub( /\n/, '' )

	# Let's only work with translations that are at least 90% complete
	if completion.to_i < 90
		next
	end

	translations.push( { :base_url => base_url, :lang_code => lang_code, :language => language } );
end

puts "Downloading valid translations for #{translations.count} languages..."

translation_maps = [
];

# Open a HTTP connection
Net::HTTP.start( 'translate.wordpress.org' ) do |http|
	begin

		# Create output directory exists
		begin
			Dir.mkdir( File.join( Dir.pwd, 'pomo' ) )
		rescue
		end

		# Iterate through each translation
		translations.each do |translation|
			puts translation[:language]

			# See if there's a way to automagically figure this out from GlotPress -- or build a big hashmap
			file_name = translation[:lang_code];
			case file_name
			when 'es'
				file_name = 'es_ES'
			when 'nl'
				file_name = 'nl_NL'
			when 'ko'
				file_name = 'ko_KR'
			when 'ru'
				file_name = 'ru_RU'
			when 'pt-br'
				file_name = 'pt_BR'
			when 'pt'
				file_name = 'pt_PT'
			when 'nb'
				file_name = 'nb_NO'
			when 'it'
				file_name = 'it_IT'
			when 'th'
				file_name = 'th'
			when 'sk'
				file_name = 'sk_SK'
			when 'fr'
				file_name = 'fr_FR'
			when 'hu'
				file_name = 'hu_HU'
			else
				file_name = file_name
			end

			file_mo   = open( File.join( Dir.pwd, 'pomo', "#{file_name}.mo" ), 'wb' )
			file_pot  = open( File.join( Dir.pwd, 'pomo', "#{file_name}.pot" ), 'wb' )

			# Download the .mo. We're writing straight to the open file rather than buffering contents in memory
			http.request_get( "#{translation[:base_url]}/export-translations?format=mo" ) do |response|
				response.read_body do |segment|
					file_mo.write( segment )
				end
			end

			# Download the .pot. We're writing straight to the open file rather than buffering contents in memory
			http.request_get( "#{translation[:base_url]}/export-translations?format=po" ) do |response|
				response.read_body do |segment|
					file_pot.write( segment )
				end
			end

			file_mo.close
			file_pot.close
		end

	end
end
