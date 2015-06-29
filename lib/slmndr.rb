## Salamander: A minimalistic ruby web crawling framework.
## Authored by: John Lawrence M. Penafiel

require 'time'
require 'thread'
require 'set'
require 'open-uri'
require 'openssl'

require 'json'
require 'open_uri_redirections'
require 'nokogiri'
require 'addressable/uri'

## Module
##     Salamander
## Description
##     The Crawler module provides an easy way for the other components of the Salamander system to perform crawling.
## Functions
##     Salamander::crawl
module Salamander

	## Function
	##     get_links
	## Description
	##     Extracts outgoing links from the HTML pointed to by the given URL string.
	## Parameters
	##     url		-	The URL of the HTML page the function is extracting links from.
	##     html		-	The HTML data to extract links from.
	def self.get_links(url, html)
		# Initialize
		uri = Addressable::URI.parse(url)
		# Parse as HTML
		_html = Nokogiri::HTML(html)
		# Get all anchors
		_html.xpath('//a').each do |l|
			# Extract hyper link
			href = l['href']
			# Skip if hyper link does not exist
			if href == nil then
				next
			end
			# Convert hyper link to URI object
			link = Addressable::URI.parse(href)
			# Skip if hyper link is not HTTP 
			if link.scheme != nil && link.scheme != 'http' && link.scheme != 'https' then
				next
			end
			# Convert hyper link to absolute form
			if link.host == nil then
				link.host = uri.host
			end
			if link.scheme == nil then
				link.scheme = uri.scheme
			end
			if link.port == nil then
				link.port = uri.port
			end
			# Remove link fragment
			link.fragment = nil
			# Yield
			yield link
		end
	end
	
	## Function
	##     crawl
	## Description
	##     Performs a restricted, unauthenticated, breadth-first crawl of the target web asset.
	##     Function blocks until all threads terminate.
	## Parameters
	##     urls		-	Required. A list of strings containing the seed URLs.
	##     args		-	Optional. Default: {}. A hash containing optional arguments for the function.
	##         visit	-	Optional. Default: nil. A lambda which accepts a URL, and returns a boolean which tells the crawler if the URL should be visited.
	##         delay	-	Optional. Default: 1. A positive float indicating the number of seconds between requests in one thread.
	##         threads  -	Optional. Default: 1. A positive integer indicating the number of allowed simultaneous requests to the target web asset.
	##         agent	-	Optional. Default: "Mozilla/5.0 (MSIE 9.0; Windows NT 6.1; Trident/5.0)". The user-agent string to be used.
	def crawl(urls, args = {})
		# Get arguments
		visit = nil
		if args[:visit] != nil then
			visit = args[:visit]
		end
		delay = 1
		if args[:delay] != nil then
			delay = args[:delay]
		end
		if delay < 0 then
			raise "delay must be a positive float"
		end
		threads = 1
		if args[:threads] != nil then
			threads = args[:threads]
		end
		if threads < 0 then
			raise "threads must be a positive integer"
		end
		agent = "Mozilla/5.0 (MSIE 9.0; Windows NT 6.1; Trident/5.0)"
		if args[:agent] != nil then
			agent = args[:agent]
		end
		# Create threads list
		_threads = []
		# Create jobs map and lock
		jobs = {}
		jlock = Mutex.new
		# Create job; Job States: 0: waiting, 1: working, 2: done
		urls.each do |url|
			jobs[:"#{url}"] = { state: 0, depth: 0 }
		end
		# Create and launch crawl threads
		for id in 1..threads
			# Create crawl thread
			thread = Thread.new do
				# Loop
				while true
					# Find job to do
					kill = true
					job_url = nil
					jlock.synchronize do
						# For each job
						jobs.each do |u, j|
							# If job is waiting
							if j[:state] == 0 then
								# Take job
								job_url = u
								j[:state] = 1
								kill = false
								break
							elsif j[:state] == 1 then
								# Some jobs are still working; anticipate more jobs in the future
								kill = false
							end
						end
					end
					# If all jobs are done, and no job is found
					if kill then
						break
					end
					# If no job found but some jobs are still being worked on, skip
					if job_url == nil then
						next
					end
					# Get job depth
					job_depth = jobs[:"#{job_url}"][:depth]
					# Get all links in page pointed to by job URL
					begin
						open("#{job_url}", { :allow_redirections => :all, ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, "User-Agent" => agent }) do |response|
							# Callback
							jlock.synchronize do
								yield "#{job_url}", response, job_depth
							end
							# If resolved URL is in scope
							if Addressable::URI.parse(response.base_uri).host == Addressable::URI.parse("#{job_url}").host then
								# Add resolved URL to job queue and mark it as complete if it does not exist yet
								jlock.synchronize do
									if jobs[:"#{response.base_uri}"] == nil then
										yield "#{response.base_uri}", response, job_depth
										jobs[:"#{response.base_uri}"] = { state: 2, depth: job_depth }
									end
								end
								# Get links for resolve URL
								Salamander::get_links(response.base_uri, response) do |link|
									# Determine if the link should be visited
									if visit.nil? || visit.call(link) then
										jlock.synchronize do
											# If link is not in job queue
											if jobs[:"#{link}"] == nil then
												# Create job for the given link
												jobs[:"#{link}"] = { state: 0, depth: job_depth + 1 }
											end
										end
									end
								end
							end
						end
					rescue
					end
					# Flag job as complete
					jlock.synchronize do
						jobs[:"#{job_url}"][:state] = 2
					end
					# Perform delay
					sleep(delay)
				end
			end
			_threads << thread
		end
		# Wait for all threads to die
		_threads.each do |_thread|
			_thread.join
		end
	end
	
	module_function :crawl

end

# For direct invocation of crawler.rb
if __FILE__ == $0 then
	# Record start time
	time = Time.new
	# Arbitrary terminal width
	twid = 70
	# Declare crawl count variable
	count = 0
	# Attempt to catch interrupt signals and unknown errors
	begin
		# Read arguments JSON from standard input
		stdin = STDIN.read
		args = nil
		begin
			args = JSON.parse(stdin)
		rescue
			puts JSON.pretty_generate({ result: "exception", message: "unable to parse json from stdin" })
			exit
		end
		# Make sure the urls parameter has been supplied
		if args['urls'] == nil then
			puts JSON.pretty_generate({ result: "misuse", message: "'urls' parameter not specified" })
			exit
		else
			# Retrieve the url parameter
			urls = args['urls']
			if !urls.kind_of?(Array) then
				puts JSON.pretty_generate({ result: "exception", message: "urls must be a list of valid URLs" })
				exit
			end
			urls.each do |url|
				begin
					Addressable::URI.parse(url)
				rescue
					puts JSON.pretty_generate({ result: "exception", message: "urls must be a list of valid URLs" })
					exit
				end
			end
			_args = {}
			# Attempt to retrieve the delay parameter
			if args['delay'] != nil then
				begin
					_args[:delay] = args['delay'].to_f
				rescue
					puts JSON.pretty_generate({ result: "exception", message: "delay must be a float" })
					exit
				end
			end
			# Attempt to retrieve the threads parameter
			if args['threads'] != nil then
				begin
					_args[:threads] = args['threads'].to_i
				rescue
					puts JSON.pretty_generate({ result: "exception", message: "threads must be an integer" })
					exit
				end
			end
			# Attempt to retrieve the agent parameter
			if args['agent'] != nil then
				_args[:agent] = args['agent']
			end
			# Begin crawl; try to catch exceptions
			begin
				# Print banner
				STDERR.puts
				STDERR.puts " Welcome to the Salamander Web Crawler Demo!"
				STDERR.puts
				STDERR.puts " This is a command-line demonstration of the Salamander Web Crawler in action."
				STDERR.puts " Press Ctrl+C at any time to interrupt the crawl."
				STDERR.puts
				STDERR.puts " Starting crawl at the following URLs:"
				urls.each do |url|
					STDERR.puts "     - #{url}"
				end
				STDERR.puts
				STDERR.print " Depth    URL"
				first = true
				# Do actual crawl
				Salamander::crawl(urls, _args) do |request, response, depth|
					begin
						# Increment crawl count
						count = count + 1
						# Truncate URL string
						if request.length > twid - 2 then
							_url = "#{request[0, twid - 5]}..."
						else
							_url = request
						end
						# Print crawl hit
						if first then
							STDERR.puts
							first = false
						end
						STDERR.puts
						STDERR.print "    #{format('%02d', depth)}    #{_url}"
						STDERR.flush
					rescue Interrupt => e
						# Catch interrupt cleanly
						STDERR.puts
						STDERR.puts
						STDERR.puts " Program terminated successfully"
						STDERR.puts " Number of Pages Crawled: #{count}"
						STDERR.puts " Running Time: #{Time.at(Time.new - time).gmtime.strftime("%H:%M:%S")}"
						break
					end
				end
			rescue => e
				puts JSON.pretty_generate({ result: "exception", message: "error encountered while crawling", inspect: e.inspect })
				exit
			end
		end
	rescue Interrupt => e
		# Catch interrupt cleanly
		STDERR.puts
		STDERR.puts
		STDERR.puts " Program terminated successfully"
		STDERR.puts " Number of Pages Crawled: #{count}"
		STDERR.puts " Running Time: #{Time.at(Time.new - time).gmtime.strftime("%H:%M:%S")}"
	rescue e
		# Print any uncaught exceptions
		puts JSON.pretty_generate({ result: "exception", message: "unknown error", inspect: e.inspect })
		exit
	end
end