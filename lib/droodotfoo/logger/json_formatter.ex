defmodule Droodotfoo.Logger.JsonFormatter do
  @moduledoc """
  JSON log formatter for production environments.

  Outputs structured JSON logs that are easier to parse in log aggregators
  like Fly.io logs, Datadog, or CloudWatch.

  ## Configuration

  In config/prod.exs or config/runtime.exs:

      config :logger, :default_handler,
        formatter: {Droodotfoo.Logger.JsonFormatter, []}

  ## Output Format

      {"timestamp":"2026-01-25T12:00:00.000Z","level":"info","message":"Request completed","metadata":{"request_id":"abc123"}}

  """

  @doc """
  Formats a log message as JSON.
  """
  def format(level, message, timestamp, metadata) do
    json =
      %{
        timestamp: format_timestamp(timestamp),
        level: level,
        message: message |> IO.iodata_to_binary() |> scrub()
      }
      |> add_metadata(metadata)
      |> Jason.encode!()

    [json, "\n"]
  rescue
    e ->
      # Still emit JSON: a single unformattable entry must not put a plain-text
      # line into the stream and break every downstream parser.
      json =
        Jason.encode!(%{
          level: level,
          message: "log formatting failed",
          error: e |> Exception.message() |> scrub()
        })

      [json, "\n"]
  end

  defp format_timestamp({date, {hour, minute, second, micro}}) do
    {year, month, day} = date

    NaiveDateTime.new!(year, month, day, hour, minute, second, micro * 1000)
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end

  defp add_metadata(json, []), do: json

  defp add_metadata(json, metadata) do
    # Filter out nil values and convert to map
    filtered =
      metadata
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.map(fn {k, v} -> {k, format_value(v)} end)
      |> Map.new()

    if map_size(filtered) > 0 do
      Map.put(json, :metadata, filtered)
    else
      json
    end
  end

  # Log messages carry bytes from anywhere: a third-party error string cut mid
  # codepoint, a latin-1 payload, a binary echoed back from a socket. Jason
  # raises on invalid UTF-8, so replace the offending bytes and keep the entry
  # rather than losing it to the rescue clause.
  defp scrub(binary) do
    if String.valid?(binary), do: binary, else: scrub(binary, <<>>)
  end

  defp scrub(<<>>, acc), do: acc

  defp scrub(<<codepoint::utf8, rest::binary>>, acc),
    do: scrub(rest, <<acc::binary, codepoint::utf8>>)

  defp scrub(<<_invalid, rest::binary>>, acc), do: scrub(rest, <<acc::binary, "?">>)

  defp format_value(v) when is_binary(v), do: scrub(v)
  defp format_value(v) when is_atom(v), do: Atom.to_string(v)
  defp format_value(v) when is_number(v), do: v
  defp format_value(v) when is_list(v), do: Enum.map(v, &format_value/1)
  defp format_value(v) when is_map(v), do: Map.new(v, fn {k, val} -> {k, format_value(val)} end)
  defp format_value(v), do: inspect(v)
end
