# Salamander: A minimalistic ruby web crawling framework.
# Authored by: John Lawrence M. Penafiel

require 'time'
require 'thread'
require 'set'
require 'open-uri'
require 'openssl'

require 'json'
require 'open_uri_redirections'
require 'nokogiri'
require 'addressable/uri'

# The module containing the Salamander framework itself.
module Salamander

	# Extracts outgoing links from the HTML pointed to by the given URL string.
	# @param url The URL of the HTML page the function is extracting links from.
	# @param html The HTML data to extract links from.
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
	
	# Performs an unauthenticated, breadth-first crawl of the target web asset.
	# Function blocks until all threads terminate.
	# This function can receive a code block like so...
	#     Salamander::crawl(urls, args) do |request, response, depth|
	#          # request: the URL string used to request the current page
	#          # response: a hash containing data pertaining to the response to the requested URL
	#          # depth: a positive integer indicating the breadth/depth of the current page, relative to one of the seed URLs
	#     end
	# Response Hash Contents
	#     base_uri:         The base_uri field of OpenURI's response
	#     meta:             The meta field of OpenURI's response
	#     status:           The status field of OpenURI's response
	#     content_type:     The content_type field of OpenURI's response
	#     charset:          The charset field of OpenURI's response
	#     content_encoding: The content_encoding field of OpenURI's response
	#     last_modified:    The last_modified field of OpenURI's response
	#     body:             Contains the body of OpenURI's response
	# Optional Arguments
	#     visit:            A lambda which accepts a URL, and returns a boolean which tells the crawler if the URL should be visited.
	#     delay:            A positive float indicating the number of seconds between requests in one thread. Defaults to 1.
	#     threads:          A positive integer indicating the number of allowed simultaneous requests to the target web asset. Defaults to 1.
	#     agent:            The user-agent string to be used. Defaults to "Mozilla/5.0 (MSIE 9.0; Windows NT 6.1; Trident/5.0)".
	# @param urls A list of strings containing the seed URLs.
	# @param args A hash containing optional arguments for the function.
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
		# Create threads list and lock
		_threads = {}
		tlock = Mutex.new
		# Create jobs map and lock
		jobs = {}
		jlock = Mutex.new
		# Create yield job list and lock
		yields = []
		ylock = Mutex.new
		# Create job; Job States: 0: waiting, 1: working, 2: done
		urls.each do |url|
			jobs[:"#{url}"] = { state: 0, depth: 0 }
		end
		# Create and launch crawl threads
		for i in 1..threads
			tlock.synchronize do
				# Create crawl thread
				thread = Thread.new do
					# Wait until all threads are created
					tlock.synchronize do
					end
					# Get thread id
					_id = Thread.current.object_id
					# Loop
					while true
						# Check if thread has been forcefully killed
						kill = false
						tlock.synchronize do
							kill = _threads[_id][:kill]
						end
						if kill then
							break
						end
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
								_response = {
									base_uri: response.base_uri,
									meta: response.meta,
									status: response.status,
									content_type: response.content_type,
									charset: response.charset,
									content_encoding: response.content_encoding,
									last_modified: response.last_modified,
									body: response.read
								}
								# Callback
								ylock.synchronize do
									yields << { request: "#{job_url}", response: _response, depth: job_depth }
								end
								# If resolved URL is in scope
								if Addressable::URI.parse(response.base_uri).host == Addressable::URI.parse("#{job_url}").host then
									# Add resolved URL to job queue and mark it as complete if it does not exist yet
									jlock.synchronize do
										if jobs[:"#{response.base_uri}"] == nil then
											jobs[:"#{response.base_uri}"] = { state: 2, depth: job_depth }
										end
									end
									# Get links for resolve URL
									Salamander::get_links(response.base_uri, _response[:body]) do |link|
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
				_threads[thread.object_id] = { thread: thread, kill: false }
			end
		end
		# Wait for all threads to die
		while true
			# Execute yields
			y = nil
			ylock.synchronize do
				y = yields.shift
			end
			if y != nil then
				tlock.synchronize do
					# Pre-emptive kill if yield breaks
					_threads.each do |id, _thread|
						_thread[:kill] = true
					end
					# Yield
					yield y[:request], y[:response], y[:depth]
					# Cancel kill if yield does not break
					_threads.each do |id, _thread|
						_thread[:kill] = false
					end
				end
				next
			end
			# Check if dead
			alive = false
			_threads.each do |id, _thread|
				alive = alive || _thread[:thread].alive?
				if alive then
					break
				end
			end
			if !alive then
				break
			end
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
			urls_hosts = Set.new
			urls.each do |url|
				urls_hosts << Addressable::URI.parse(url).host
			end
			urls.each do |url|
				begin
					Addressable::URI.parse(url)
				rescue
					puts JSON.pretty_generate({ result: "exception", message: "urls must be a list of valid URLs" })
					exit
				end
			end
			_args = { visit:
				lambda do |url|
					return urls_hosts.include?(Addressable::URI.parse(url).host)
				end
			}
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
				STDERR.puts " The crawl is restricted to the hosts inside the URL list that was provided."
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
				puts JSON.pretty_generate({ result: "exception", message: "error encountered while crawling", backtrace: e.backtrace })
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
		puts JSON.pretty_generate({ result: "exception", message: "unknown error", backtrace: e.backtrace })
		exit
	end
end
