defmodule Droodotfoo.OG.SvgTest do
  use ExUnit.Case, async: true

  alias Droodotfoo.Content.Posts.Post
  alias Droodotfoo.OG.{Card, Svg}

  @golden "test/fixtures/og/site.svg"

  describe "render/1" do
    test "site card matches the golden snapshot" do
      # Regenerate with:
      #   Card.site(:online) |> Svg.render() |> then(&File.write!("#{@golden}", &1))
      assert Svg.render(Card.site(:online)) == File.read!(@golden)
    end

    test "declares the Open Graph canvas size" do
      svg = Svg.render(Card.site(:online))

      assert svg =~ ~s|width="1200"|
      assert svg =~ ~s|height="630"|
      assert svg =~ ~s|viewBox="0 0 1200 630"|
    end

    test "is deterministic" do
      assert Svg.render(Card.site(:online)) == Svg.render(Card.site(:online))
    end

    test "renders every nav item in site order" do
      svg = Svg.render(Card.site(:online))

      labels =
        ~r/>(?:\S+) ([A-Za-z]+)<\/text>/
        |> Regex.scan(svg, capture: :all_but_first)
        |> List.flatten()

      assert labels == ~w(Home About Now Projects Writing Sitemap Contact)
    end

    test "degraded status swaps the word and the colour" do
      online = Svg.render(Card.site(:online))
      degraded = Svg.render(Card.site(:degraded))

      assert online =~ ">online</text>"
      assert online =~ "#00ff41"

      assert degraded =~ ">degraded</text>"
      assert degraded =~ "#ffb000"
      refute degraded =~ "#00ff41"
    end

    test "never renders an offline state" do
      refute Svg.render(Card.site(:online)) =~ "offline"
      refute Svg.render(Card.site(:degraded)) =~ "offline"
    end
  end

  describe "post cards" do
    test "uppercases the title and carries the post author" do
      svg = post_svg(title: "Finding the Agalma", author: "DROO AMOR")

      assert svg =~ "FINDING THE"
      assert svg =~ "AGALMA"
      assert svg =~ ">DROO AMOR</text>"
    end

    test "escapes XML metacharacters so the document stays parseable" do
      svg =
        post_svg(
          title: "Tom & Jerry <script> \"quoted\"",
          description: "Ampersands & angle brackets < > everywhere"
        )

      # Wrapping happens before escaping, so line widths reflect real
      # characters rather than entity lengths.
      assert svg =~ ">TOM &amp; JERRY</text>"
      assert svg =~ ">&lt;SCRIPT&gt; &quot;QUOTED&quot;</text>"
      assert svg =~ ">Ampersands &amp; angle brackets</text>"
      refute svg =~ "<script>"

      # The whole document must still parse as XML.
      assert_valid_xml(svg)
    end

    test "escapes apostrophes, which real titles contain" do
      svg = post_svg(title: "Xochi: Why We're Building ETH's Friendly Dark Pool")

      assert svg =~ "&apos;"
      assert_valid_xml(svg)
    end

    test "long titles shrink instead of overflowing" do
      svg = post_svg(title: "Xochi: Why We're Building ETH's Friendly Dark Pool")

      assert svg =~ ~s|font-size="40"|
    end

    test "short titles keep the full display size" do
      svg = post_svg(title: "Clean Air")

      assert svg =~ ~s|font-size="120"|
    end

    test "falls back to the site author when the post has none" do
      svg = post_svg(title: "Untitled", author: nil)

      assert svg =~ ">#{Droodotfoo.Site.author()}</text>"
    end
  end

  describe "escape/1" do
    test "escapes the five XML metacharacters" do
      assert Svg.escape(~s(& < > " ')) == "&amp; &lt; &gt; &quot; &apos;"
    end

    test "strips control characters that would corrupt the document" do
      assert Svg.escape("a\x00b\x1Fc") == "abc"
    end
  end

  # xmerl is strict: an unescaped & or < makes it raise, which is exactly the
  # failure mode that would silently break a post's card.
  defp assert_valid_xml(svg) do
    assert {_doc, _rest} = :xmerl_scan.string(String.to_charlist(svg), quiet: true)
  end

  defp post_svg(opts) do
    %Post{
      slug: "test-post",
      title: Keyword.get(opts, :title, "Test"),
      description: Keyword.get(opts, :description, "A description"),
      author: Keyword.get(opts, :author, "DROO AMOR"),
      date: ~D[2026-01-01]
    }
    |> Card.post(:online)
    |> Svg.render()
  end
end
