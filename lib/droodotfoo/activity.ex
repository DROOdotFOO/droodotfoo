defmodule Droodotfoo.Activity do
  @moduledoc """
  Aggregates contribution-calendar activity across sources.

  Currently merges `Droodotfoo.GitHub.Activity` (live API) with
  `Droodotfoo.Forgejo.Activity` (static JSON regenerated from a local
  FFmpeg clone). Owns the PubSub topic and broadcast for the contribution
  graph; the source modules stay pure fetchers.
  """

  require Logger

  alias Droodotfoo.GitHub.Activity, as: GitHub
  alias Droodotfoo.Forgejo.Activity, as: Forgejo

  @topic "contributions"

  @empty_day %{date: "", count: 0, level: 0, repos: [], activity_types: []}

  @type day :: %{
          date: String.t(),
          count: non_neg_integer(),
          level: 0..4,
          repos: [String.t()],
          activity_types: [String.t()]
        }

  @type source :: :graphql | :rest | :ffmpeg

  @type data :: %{
          days: [day()],
          total: non_neg_integer(),
          sources: [source()]
        }

  @spec empty_day() :: day()
  def empty_day, do: @empty_day

  @doc "Subscribe to contribution data updates via PubSub."
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(Droodotfoo.PubSub, @topic)

  @spec fetch() :: {:ok, data()} | {:error, term()}
  def fetch do
    case GitHub.fetch() do
      {:ok, gh} -> {:ok, merge_forgejo(gh)}
      {:error, _} = err -> err
    end
  end

  @doc "Fetch and broadcast merged data to all subscribers."
  @spec fetch_and_broadcast() :: {:ok, data()} | {:error, term()}
  def fetch_and_broadcast do
    result = fetch()

    case result do
      {:ok, data} ->
        Phoenix.PubSub.broadcast(Droodotfoo.PubSub, @topic, {:contribution_data, data})

      _ ->
        :ok
    end

    result
  end

  @doc """
  Re-quantize a count to a 0..4 level given the max count in the dataset.

  Exposed because `Droodotfoo.GitHub.Activity` reuses it on the REST fallback
  path and the merge step here uses it after combining sources.
  """
  @spec quantize_level(non_neg_integer(), non_neg_integer()) :: 0..4
  def quantize_level(0, _), do: 0
  def quantize_level(_, 0), do: 1

  def quantize_level(count, max) do
    case count / max do
      r when r <= 0.25 -> 1
      r when r <= 0.50 -> 2
      r when r <= 0.75 -> 3
      _ -> 4
    end
  end

  # -- merging --

  defp merge_forgejo(%{days: gh_days, total: gh_total, source: gh_source}) do
    case Forgejo.fetch() do
      {:ok, []} ->
        %{days: gh_days, total: gh_total, sources: [gh_source]}

      {:ok, fj_days} ->
        by_date = Map.new(fj_days, &{&1.date, &1})

        combined_days =
          Enum.map(gh_days, fn day ->
            case Map.get(by_date, day.date) do
              nil ->
                day

              %{count: fj_count, repos: fj_repos, activity_types: fj_types} ->
                %{
                  day
                  | count: day.count + fj_count,
                    repos: Enum.uniq(day.repos ++ fj_repos),
                    activity_types: Enum.uniq(day.activity_types ++ fj_types)
                }
            end
          end)

        relevelled = relevel(combined_days)
        fj_total = Enum.reduce(fj_days, 0, fn day, acc -> acc + day.count end)

        %{days: relevelled, total: gh_total + fj_total, sources: [gh_source, :ffmpeg]}

      {:error, reason} ->
        Logger.warning("Forgejo activity unavailable: #{inspect(reason)}")
        %{days: gh_days, total: gh_total, sources: [gh_source]}
    end
  end

  defp relevel(days) do
    max_count = days |> Enum.map(& &1.count) |> Enum.max(fn -> 0 end)
    Enum.map(days, fn day -> %{day | level: quantize_level(day.count, max_count)} end)
  end
end
