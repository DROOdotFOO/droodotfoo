defmodule Droodotfoo.Forgejo.Activity do
  @moduledoc """
  Loads FFmpeg contribution activity from a static JSON file at
  `priv/ffmpeg_activity.json`.

  Why static: code.ffmpeg.org and git.ffmpeg.org are both Anubis-protected
  (proof-of-work bot challenge), so a runtime fetch from server-side Elixir
  is not viable. The JSON is regenerated locally from a checked-out FFmpeg
  clone via `mix ffmpeg_activity.refresh` and committed to the repo.

  Returns days in the same shape as `Droodotfoo.GitHub.Activity` so the
  top-level `Droodotfoo.Activity` aggregator can merge them.
  """

  require Logger

  @repo_label "FFmpeg"
  @activity_type "commits"

  @type day :: %{
          date: String.t(),
          count: non_neg_integer(),
          repos: [String.t()],
          activity_types: [String.t()]
        }

  @spec fetch() :: {:ok, [day()]} | {:error, term()}
  def fetch do
    path = json_path()

    case File.read(path) do
      {:ok, raw} ->
        case Jason.decode(raw) do
          {:ok, entries} when is_list(entries) ->
            {:ok, Enum.map(entries, &to_day/1)}

          {:ok, _} ->
            {:error, :invalid_json_shape}

          {:error, reason} ->
            Logger.warning("Forgejo activity JSON decode failed: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        Logger.warning("Forgejo activity JSON read failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc "Absolute path to the activity JSON inside this app's priv directory."
  @spec json_path() :: String.t()
  def json_path do
    Application.app_dir(:droodotfoo, "priv/ffmpeg_activity.json")
  end

  defp to_day(%{"date" => date, "count" => count}) when is_binary(date) and is_integer(count) do
    %{
      date: date,
      count: count,
      repos: [@repo_label],
      activity_types: [@activity_type]
    }
  end

  defp to_day(_), do: nil
end
