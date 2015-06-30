# Salamander
A minimalistic ruby web crawling framework.

## Installation
To install Salamander, simply invoke the following command on your console:
```
gem install slmndr
```

## Usage
To use Salamander, all you need to do is call the Salamander::crawl method, like so:
```ruby
require 'slmndr'

# list of URLs to start from
urls = [ "http://www.google.com/" ]
# list of optional arguments
args = {
	visit: lambda do |url|
		return true # a lambda which accepts a URL and returns true if that URL should be visited
	end,
	delay: 1, # a positive float indicating the number of seconds between requests in one thread
	threads: 1, # a positive integer indicating the number of allowed simultaneous requests to the target web asset
	agent: "Mozilla/5.0 (MSIE 9.0; Windows NT 6.1; Trident/5.0)" # the user-agent string to use for requests
}
# call the crawl method
Salamander::crawl(urls, args) do |request, response, depth|
	# request:  the URL string used to request the current page
	# response: a hash containing data pertaining to the response to the requested URL
	#     base_uri:         The base_uri field of OpenURI's response
	#     meta:             The meta field of OpenURI's response
	#     status:           The status field of OpenURI's response
	#     content_type:     The content_type field of OpenURI's response
	#     charset:          The charset field of OpenURI's response
	#     content_encoding: The content_encoding field of OpenURI's response
	#     last_modified:    The last_modified field of OpenURI's response
	#     body:             Contains the body of OpenURI's response
	# depth:    a positive integer indicating the breadth/depth of the current page, relative to one of the seed URLs
	puts "Just visited #{request}"
end
```

### Proxy
To use a proxy, simply set your HTTP_PROXY and HTTPS_PROXY environment variables.

## Author(s)
* John Lawrence M. Penafiel (penafieljlm)

## Homepage
* https://rubygems.org/gems/slmndr
