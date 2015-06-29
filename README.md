# Salamander
A minimalistic ruby web crawling framework.

## Usage
To use Salamander, all you need to do is call the Salamander::crawl method, like so:
```
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
	# request - the URL used to request the current page
	# response - an OpenURI HTTP response object representing the content of the requested URL
	# depth - a positive integer indicating the breadth/depth of the current page, relative to one of the seed URLs
	puts "Just visited #{request}"
end
```

### Proxy
To use a proxy, simply set your HTTP_PROXY and HTTPS_PROXY environment variables.

## Author(s)
* John Lawrence M. Penafiel