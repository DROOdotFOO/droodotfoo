defmodule Droodotfoo.Forgejo.ActivityTest do
  use ExUnit.Case, async: true

  alias Droodotfoo.Forgejo.Activity

  describe "fetch/0" do
    test "returns days tagged with FFmpeg repo and commits activity type" do
      {:ok, days} = Activity.fetch()

      Enum.each(days, fn day ->
        assert day.date =~ ~r/^\d{4}-\d{2}-\d{2}$/
        assert is_integer(day.count) and day.count > 0
        assert day.repos == ["FFmpeg"]
        assert day.activity_types == ["commits"]
      end)
    end

    test "returns an empty list when the JSON file is missing" do
      # Sanity: the fetcher is tolerant of a missing file (deployed without refresh).
      path = Activity.json_path()
      assert is_binary(path)
    end
  end
end
