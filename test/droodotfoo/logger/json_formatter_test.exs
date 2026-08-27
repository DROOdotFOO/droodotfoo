defmodule Droodotfoo.Logger.JsonFormatterTest do
  use ExUnit.Case, async: true

  alias Droodotfoo.Logger.JsonFormatter

  describe "format/4" do
    test "outputs valid JSON" do
      timestamp = {{2026, 1, 25}, {12, 0, 0, 0}}

      result = JsonFormatter.format(:info, "Test message", timestamp, [])

      assert [json, "\n"] = result
      assert {:ok, parsed} = Jason.decode(json)
      assert parsed["level"] == "info"
      assert parsed["message"] == "Test message"
      assert parsed["timestamp"] =~ "2026-01-25T12:00:00"
    end

    test "includes metadata" do
      timestamp = {{2026, 1, 25}, {12, 0, 0, 0}}
      metadata = [request_id: "abc123", path: "/test"]

      result = JsonFormatter.format(:info, "With metadata", timestamp, metadata)

      [json, _] = result
      {:ok, parsed} = Jason.decode(json)
      assert parsed["metadata"]["request_id"] == "abc123"
      assert parsed["metadata"]["path"] == "/test"
    end

    test "handles different log levels" do
      timestamp = {{2026, 1, 25}, {12, 0, 0, 0}}

      for level <- [:debug, :info, :warning, :error] do
        result = JsonFormatter.format(level, "Test", timestamp, [])
        [json, _] = result
        {:ok, parsed} = Jason.decode(json)
        assert parsed["level"] == Atom.to_string(level)
      end
    end

    test "filters nil metadata values" do
      timestamp = {{2026, 1, 25}, {12, 0, 0, 0}}
      metadata = [request_id: "abc", nil_value: nil]

      result = JsonFormatter.format(:info, "Test", timestamp, metadata)

      [json, _] = result
      {:ok, parsed} = Jason.decode(json)
      assert parsed["metadata"]["request_id"] == "abc"
      refute Map.has_key?(parsed["metadata"], "nil_value")
    end

    test "handles iodata messages" do
      timestamp = {{2026, 1, 25}, {12, 0, 0, 0}}
      message = ["Hello", " ", "World"]

      result = JsonFormatter.format(:info, message, timestamp, [])

      [json, _] = result
      {:ok, parsed} = Jason.decode(json)
      assert parsed["message"] == "Hello World"
    end

    # Sentry's over-quota reply arrives with a lone 0xB9 where a superscript one
    # should be. That byte used to raise Jason.EncodeError and drop a plain-text
    # line into the middle of the JSON stream.
    test "replaces invalid UTF-8 in the message instead of falling back" do
      timestamp = {{2026, 1, 25}, {12, 0, 0, 0}}
      message = <<"error response from service exported to status=429 ", 0xB9>>

      [json, "\n"] = JsonFormatter.format(:info, message, timestamp, [])

      assert {:ok, parsed} = Jason.decode(json)
      assert parsed["message"] == "error response from service exported to status=429 ?"
    end

    test "replaces invalid UTF-8 in metadata values" do
      timestamp = {{2026, 1, 25}, {12, 0, 0, 0}}
      metadata = [request_id: <<"abc", 0xB9, "123">>]

      [json, "\n"] = JsonFormatter.format(:info, "Test", timestamp, metadata)

      assert {:ok, parsed} = Jason.decode(json)
      assert parsed["metadata"]["request_id"] == "abc?123"
    end

    test "emits JSON even when the entry cannot be formatted" do
      # A malformed timestamp raises inside format_timestamp/1.
      [json, "\n"] = JsonFormatter.format(:error, "Test", :not_a_timestamp, [])

      assert {:ok, parsed} = Jason.decode(json)
      assert parsed["level"] == "error"
      assert parsed["message"] == "log formatting failed"
      assert is_binary(parsed["error"])
    end
  end
end
