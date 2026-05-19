#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APPCAST_PATH="${APPCAST_PATH:-$ROOT_DIR/docs/appcast.xml}"
VERSION="${1:-}"
BUILD="${2:-}"
DMG_URL="${3:-}"
DMG_LENGTH="${4:-}"
ED_SIGNATURE="${5:-}"

if [[ -z "$VERSION" || -z "$BUILD" || -z "$DMG_URL" || -z "$DMG_LENGTH" || -z "$ED_SIGNATURE" ]]; then
  echo "Usage: scripts/update_appcast.sh <version> <build> <dmg-url> <length> <ed-signature>" >&2
  exit 64
fi

ruby -r rexml/document -r time - "$APPCAST_PATH" "$VERSION" "$BUILD" "$DMG_URL" "$DMG_LENGTH" "$ED_SIGNATURE" <<'RUBY'
path, version, build, dmg_url, length, signature = ARGV
xml = File.read(path)
document = REXML::Document.new(xml)
channel = REXML::XPath.first(document, "/rss/channel")
abort("Missing /rss/channel in #{path}") unless channel

channel.delete_element("item")

item = REXML::Element.new("item")
title = item.add_element("title")
title.text = "MusicBar #{version}"
pub_date = item.add_element("pubDate")
pub_date.text = Time.now.rfc2822
sparkle_version = item.add_element("sparkle:version")
sparkle_version.text = build
short_version = item.add_element("sparkle:shortVersionString")
short_version.text = version
minimum_system = item.add_element("sparkle:minimumSystemVersion")
minimum_system.text = "13.0"
enclosure = item.add_element("enclosure")
enclosure.add_attribute("url", dmg_url)
enclosure.add_attribute("sparkle:edSignature", signature)
enclosure.add_attribute("length", length)
enclosure.add_attribute("type", "application/octet-stream")

channel.add_element(item)

formatter = REXML::Formatters::Pretty.new(2)
formatter.compact = true
File.open(path, "w") do |file|
  formatter.write(document, file)
  file.write("\n")
end
RUBY

echo "$APPCAST_PATH"
