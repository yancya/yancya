require "rss"
require "open-uri"

module RadioReadme
  FEED_URL = "https://podcast.nantyara.com/feed.xml"
  README_PATH = File.expand_path("../README.md", __dir__)
  MARKER_START = "<!-- radio:start -->"
  MARKER_END = "<!-- radio:end -->"
  EPISODE_COUNT = 3

  class FeedError < StandardError; end
  class MarkerError < StandardError; end

  module_function

  def build_section(feed_xml)
    feed = parse_feed(feed_xml)

    feed.items.first(EPISODE_COUNT).map do |item|
      date = item.pubDate.strftime("%Y-%m-%d")
      "- [#{item.title}](#{item.link}) (#{date})"
    end.join("\n")
  end

  def update(readme_content, feed_xml)
    unless readme_content.include?(MARKER_START) && readme_content.include?(MARKER_END)
      raise MarkerError, "README is missing #{MARKER_START} / #{MARKER_END} markers"
    end

    section = build_section(feed_xml)
    pattern = /#{Regexp.escape(MARKER_START)}.*?#{Regexp.escape(MARKER_END)}/m
    replacement = "#{MARKER_START}\n#{section}\n#{MARKER_END}"

    readme_content.sub(pattern, replacement)
  end

  def run(readme_path: README_PATH, feed_source: -> { URI.open(FEED_URL, &:read) })
    feed_xml = feed_source.call
    original = File.read(readme_path)
    updated = update(original, feed_xml)

    return false if updated == original

    File.write(readme_path, updated)
    true
  rescue FeedError, MarkerError
    false
  end

  def parse_feed(feed_xml)
    RSS::Parser.parse(feed_xml, false)
  rescue RSS::Error, RuntimeError => e
    raise FeedError, e.message
  end
  private_class_method :parse_feed
end

RadioReadme.run if $PROGRAM_NAME == __FILE__
