defmodule DroodotfooWeb.Wiki.HelpersTest do
  use ExUnit.Case, async: true

  alias DroodotfooWeb.Wiki.Helpers

  describe "format_date/1" do
    test "formats a DateTime as YYYY-MM-DD" do
      dt = ~U[2026-06-07 14:33:52Z]

      assert Helpers.format_date(dt) == "2026-06-07"
    end

    test "formats a NaiveDateTime as YYYY-MM-DD" do
      dt = ~N[2026-06-07 14:33:52]

      assert Helpers.format_date(dt) == "2026-06-07"
    end

    test "returns nil for nil input" do
      assert Helpers.format_date(nil) == nil
    end
  end

  describe "format_datetime/1" do
    test "formats a DateTime as YYYY-MM-DD HH:MM" do
      dt = ~U[2026-06-07 14:33:52Z]

      assert Helpers.format_datetime(dt) == "2026-06-07 14:33"
    end

    test "returns nil for nil input" do
      assert Helpers.format_datetime(nil) == nil
    end
  end
end
