require "minitest/autorun"
require_relative "../scripts/update_readme"

class UpdateReadmeTest < Minitest::Test
  FIXTURES = File.join(__dir__, "fixtures")

  README_TEMPLATE = <<~MD
    ### Hi there 👋

    #### なんちゃラジオ 最新エピソード

    <!-- radio:start -->
    - old entry that should be replaced
    <!-- radio:end -->

    #### Tech Stack
  MD

  def sample_feed
    File.read(File.join(FIXTURES, "sample_feed.xml"))
  end

  def broken_feed
    File.read(File.join(FIXTURES, "broken_feed.xml"))
  end

  def test_builds_section_with_latest_three_episodes_only
    section = RadioReadme.build_section(sample_feed)

    assert_includes section, "第443回「髪切ったよん」"
    assert_includes section, "第442回「夢で食べたあのパンが食べたい」"
    assert_includes section, "第441回「塊魂は顔が浮腫む」"
    refute_includes section, "第440回「昔の話」"
  end

  def test_section_includes_link_and_date
    section = RadioReadme.build_section(sample_feed)

    assert_includes section, "https://podcast.nantyara.com/episode/443"
    assert_includes section, "2026-07-03"
  end

  def test_update_replaces_only_the_marked_region
    updated = RadioReadme.update(README_TEMPLATE, sample_feed)

    assert_includes updated, "第443回「髪切ったよん」"
    refute_includes updated, "old entry that should be replaced"
    assert updated.start_with?("### Hi there 👋")
    assert_includes updated, "#### Tech Stack"
  end

  def test_update_is_idempotent
    once = RadioReadme.update(README_TEMPLATE, sample_feed)
    twice = RadioReadme.update(once, sample_feed)

    assert_equal once, twice
  end

  def test_update_raises_on_broken_feed_without_touching_input
    error = assert_raises(RadioReadme::FeedError) do
      RadioReadme.update(README_TEMPLATE, broken_feed)
    end

    assert_kind_of StandardError, error
  end

  def test_update_raises_when_markers_are_missing
    readme_without_markers = "### Hi there 👋\n"

    assert_raises(RadioReadme::MarkerError) do
      RadioReadme.update(readme_without_markers, sample_feed)
    end
  end

  def test_run_leaves_readme_untouched_when_feed_fetch_fails
    Dir.mktmpdir do |dir|
      readme_path = File.join(dir, "README.md")
      File.write(readme_path, README_TEMPLATE)

      result = RadioReadme.run(readme_path: readme_path, feed_source: -> { raise RadioReadme::FeedError, "boom" })

      assert_equal false, result
      assert_equal README_TEMPLATE, File.read(readme_path)
    end
  end

  def test_run_updates_readme_when_feed_fetch_succeeds
    Dir.mktmpdir do |dir|
      readme_path = File.join(dir, "README.md")
      File.write(readme_path, README_TEMPLATE)

      result = RadioReadme.run(readme_path: readme_path, feed_source: -> { sample_feed })

      assert_equal true, result
      assert_includes File.read(readme_path), "第443回「髪切ったよん」"
    end
  end
end
