#!/usr/bin/env ruby

#
# Scrape Safeway internal API and return a list of available delivery
# slots for the next several days.
#
# Note: You need to populate config.yaml with the following values
#

require 'json'
require 'net/http'
require 'yaml'
require 'pp'
require 'openssl'
require 'csv'

# format string for url
URL_FORMAT = "https://www.safeway.com/abs/pub/xapi/erums/checkoutservice/api/v1/checkout/slots?slotPlan=STANDARD&slotDate=%<date>s&deliveryType=UNATTENDED&serviceType=DELIVERY&storeId=%<store_id>s&fulfillmentType=DELIVERY"

unless ARGV.size > 0
  warn 'Usage: #$0 config.yaml'
  exit -1
end

# load config, check for required keys
config = YAML.load(File.read(ARGV.shift))

# check for required config keys
missing_keys = %w{store_id}.select { |key| !config.key?(key) }
if missing_keys.size > 0
	raise "missing required config keys: %s" % [missing_keys.join(', ')]
end

# build url
url = config['url'] || URL_FORMAT % {
  store_id: config['store_id'],
  date:     Time.now.strftime('%Y-%m-%d'),
}

# build uri from uri
uri = URI(url)

# build request
req = Net::HTTP::Get.new(uri)
# pp uri

# set request headers
(config['headers'] || {}).each do |key, val|
  req[key] = val
end

# request data, get response, parse json
data = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
  JSON.parse(http.request(req).body)
end

# print results
CSV(STDOUT) do |csv|
  csv << %w{date num_available_slots}

  slots = data['availableSlots']

  if slots && slots.size > 0
    slots.each do |row|
      row.keys.sort.each do |date|
        csv << [date, row[date]['slots'].size]
      end
    end
  end
end
