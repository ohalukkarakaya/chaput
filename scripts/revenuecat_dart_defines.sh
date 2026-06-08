#!/bin/sh
set -eu

keys_file="${1:-revenuecat.keys.json}"
[ -f "$keys_file" ] || exit 0

/usr/bin/ruby -rjson -rbase64 -e '
path = ARGV.fetch(0)
allowed = %w[
  REVENUECAT_API_KEY
  REVENUECAT_IOS_API_KEY
  REVENUECAT_ANDROID_API_KEY
  REVENUECAT_ENTITLEMENT_ID
]
json = JSON.parse(File.read(path))
defines = allowed.map do |key|
  value = json[key]
  next if value.nil? || value.to_s.strip.empty?

  Base64.strict_encode64("#{key}=#{value}")
end.compact
print defines.join(",")
' "$keys_file"
