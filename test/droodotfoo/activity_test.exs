defmodule Droodotfoo.ActivityTest do
  use ExUnit.Case, async: true

  alias Droodotfoo.Activity

  describe "quantize_level/2" do
    test "zero count maps to level 0 regardless of max" do
      assert Activity.quantize_level(0, 100) == 0
      assert Activity.quantize_level(0, 0) == 0
    end

    test "any non-zero count with max 0 maps to level 1" do
      assert Activity.quantize_level(5, 0) == 1
    end

    test "quartile boundaries map as documented" do
      assert Activity.quantize_level(25, 100) == 1
      assert Activity.quantize_level(50, 100) == 2
      assert Activity.quantize_level(75, 100) == 3
      assert Activity.quantize_level(100, 100) == 4
    end
  end

  describe "empty_day/0" do
    test "returns a placeholder shape compatible with rendering" do
      day = Activity.empty_day()
      assert day.date == ""
      assert day.count == 0
      assert day.level == 0
      assert day.repos == []
      assert day.activity_types == []
    end
  end
end
