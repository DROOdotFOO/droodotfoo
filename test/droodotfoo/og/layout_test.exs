defmodule Droodotfoo.OG.LayoutTest do
  use ExUnit.Case, async: true

  alias Droodotfoo.OG.{FontMetrics, Layout, Renderer}

  describe "vendored font" do
    test "matches the metrics the layout arithmetic is built on" do
      for path <- Renderer.font_files() do
        assert {:ok, metrics} = FontMetrics.read(path)

        assert metrics.units_per_em == 2000
        assert metrics.advance_width == 1240

        # One advance for every glyph: the card positions text by multiplying
        # character counts, which is only valid for a true monospace font.
        assert metrics.number_of_h_metrics == 2

        assert_in_delta FontMetrics.advance_ratio(metrics), Layout.advance_ratio(), 0.0001
      end
    end

    test "both weights are present" do
      assert Enum.all?(Renderer.font_files(), &File.regular?/1)
      assert length(Renderer.font_files()) == 2
    end
  end

  describe "advance/2" do
    test "scales with font size" do
      assert Layout.advance(100) == 62.0
      assert Layout.advance(22) == 13.64
    end

    test "applies letter spacing in em" do
      assert Layout.advance(120, -0.02) == 72.0
    end
  end

  describe "wrap/5" do
    test "wraps on word boundaries within the line budget" do
      assert {:ok, ["FINDING THE", "AGALMA"]} =
               Layout.wrap("FINDING THE AGALMA", 646, 96, 2, -0.02)
    end

    test "reports too_long when the text needs more lines" do
      assert :too_long = Layout.wrap("FINDING THE AGALMA", 646, 120, 2, -0.02)
    end

    test "hard-splits a single word longer than the line" do
      # 11 characters fit per line at 96px, so 20 of them split across two.
      assert {:ok, [first, second]} = Layout.wrap(String.duplicate("A", 20), 646, 96, 2, -0.02)
      assert String.length(first) == 11
      assert String.length(second) == 9
    end

    test "gives up when a hard-split word needs more lines than allowed" do
      assert :too_long = Layout.wrap(String.duplicate("A", 30), 646, 96, 2, -0.02)
    end
  end

  describe "fit/5" do
    test "picks the largest size that fits in two lines" do
      assert {120, ["DROO.FOO"]} =
               Layout.fit("DROO.FOO", Layout.title_sizes(), 646, 2, -0.02)
    end

    test "shrinks long titles rather than truncating them" do
      title = String.upcase("Xochi: Why We're Building ETH's Friendly Dark Pool")

      assert {size, lines} = Layout.fit(title, Layout.title_sizes(), 646, 2, -0.02)
      assert size == 40
      assert length(lines) == 2
      refute Enum.any?(lines, &String.contains?(&1, "…"))
      assert Enum.join(lines, " ") == title
    end

    test "shrinks rather than splitting a word across lines" do
      # WIKI.DROO.FOO is one unbreakable token: at 120 it fits in two lines
      # only as "WIKI.DRO" / "O.FOO", which is worse than a smaller whole one.
      assert {size, [line]} = Layout.fit("WIKI.DROO.FOO", Layout.title_sizes(), 646, 2, -0.02)

      assert line == "WIKI.DROO.FOO"
      assert size < Layout.title_size()
    end

    test "splits a word only when no size avoids it" do
      unbreakable = String.duplicate("A", 200)

      assert {_size, lines} = Layout.fit(unbreakable, Layout.title_sizes(), 646, 2, -0.02)
      assert length(lines) == 2
    end

    test "truncates with an ellipsis only when the smallest size still overflows" do
      long = String.duplicate("word ", 200)

      assert {size, lines} = Layout.fit(long, Layout.description_sizes(), 646, 2)
      assert size == List.last(Layout.description_sizes())
      assert length(lines) == 2
      assert lines |> List.last() |> String.ends_with?("…")
    end

    test "every real post title fits without truncation" do
      titles = [
        "Building DROO.FOO: Module 1 Content Infrastructure.",
        "Clean Air",
        "Raxol: The Terminal For My Gundam",
        "Finding the Agalma",
        "Xochi: Why We're Building ETH's Friendly Dark Pool"
      ]

      for title <- titles do
        {_size, lines} = Layout.fit(String.upcase(title), Layout.title_sizes(), 646, 2, -0.02)
        refute Enum.any?(lines, &String.contains?(&1, "…")), "truncated: #{title}"
      end
    end
  end

  describe "title_baseline/1" do
    test "keeps the cap top fixed as the font shrinks" do
      # The title is top-aligned, so the baseline moves with the cap height.
      assert Layout.title_baseline(120) == 192.6
      assert Layout.title_baseline(40) == 134.2
    end
  end
end
