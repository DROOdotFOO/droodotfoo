defmodule Droodotfoo.ContributionsTest do
  use ExUnit.Case, async: true

  alias Droodotfoo.Contributions

  describe "all/0" do
    test "returns all contributions as structs" do
      contribs = Contributions.all()

      assert length(contribs) >= 6
      assert Enum.all?(contribs, &is_struct(&1, Contributions))
    end

    test "every contribution has required fields populated" do
      Enum.each(Contributions.all(), fn c ->
        assert is_binary(c.project)
        assert is_binary(c.title)
        assert is_binary(c.description)
        assert is_binary(c.url)
        assert c.type in [:merged, :standard, :extension, :docs]
        assert is_binary(c.date)
        assert is_list(c.tags)
      end)
    end

    test "results are sorted newest first by date" do
      dates = Contributions.all() |> Enum.map(& &1.date)
      assert dates == Enum.sort(dates, :desc)
    end

    test "includes the FFmpeg upstream contribution" do
      ffmpeg = Enum.find(Contributions.all(), &(&1.project == "FFmpeg"))

      assert ffmpeg
      assert ffmpeg.type == :merged
      assert "NEON" in ffmpeg.tags
    end

    test "includes the ERC-8262 standard contribution" do
      erc = Enum.find(Contributions.all(), &(&1.project == "Ethereum ERCs"))

      assert erc
      assert erc.type == :standard
      assert erc.title =~ "ERC-8262"
    end
  end

  describe "recent/1" do
    test "returns the requested number of items" do
      assert length(Contributions.recent(3)) == 3
      assert length(Contributions.recent(1)) == 1
    end

    test "returns the newest contributions" do
      [first | _] = Contributions.recent(1)
      [all_first | _] = Contributions.all()

      assert first == all_first
    end

    test "caps at available contributions when n is larger" do
      total = length(Contributions.all())

      assert length(Contributions.recent(total + 50)) == total
    end
  end

  describe "type_label/1" do
    test "renders human-readable labels for each type" do
      assert Contributions.type_label(:merged) == "merged"
      assert Contributions.type_label(:standard) == "draft ERC"
      assert Contributions.type_label(:extension) == "extension"
      assert Contributions.type_label(:docs) == "docs"
    end

    test "falls back to a generic label for unknown types" do
      assert Contributions.type_label(:unknown_thing) == "shipped"
    end
  end
end
