defmodule Droodotfoo.OG.Status do
  @moduledoc """
  Site status shown on the Open Graph card, refreshed in the background.

  The check runs on a timer rather than on the request path. `Repo.query/3`
  bounds the query but not the connection checkout queue, so a saturated pool
  would stall image requests; and the usual `Task.async` escape hatch is worse,
  because `async` links and a crashing task takes the caller with it before
  `yield` returns.

  There is no `:offline`. The card is only ever rendered by a running server,
  so the honest worst case is `:degraded`.
  """

  use GenServer

  alias Droodotfoo.Performance.Cache

  @namespace :og
  @key :status

  @interval :timer.seconds(60)
  # Outlives the refresh interval so a slow tick reuses the last value rather
  # than falling back to the default.
  @ttl :timer.minutes(5)
  @db_timeout 500

  @type t :: :online | :degraded

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Last observed status. Defaults to `:online` when nothing has been recorded:
  we are answering a request, so absence of evidence is not evidence of
  failure.
  """
  @spec get() :: t()
  def get do
    case Cache.get(@namespace, @key) do
      {:ok, status} -> status
      :error -> :online
    end
  end

  @impl true
  def init(_opts) do
    send(self(), :refresh)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:refresh, state) do
    Cache.put(@namespace, @key, probe(), ttl: @ttl)
    Process.send_after(self(), :refresh, @interval)
    {:noreply, state}
  end

  defp probe do
    if database_up?() and alive?(Droodotfoo.PubSub) and alive?(DroodotfooWeb.Endpoint) do
      :online
    else
      :degraded
    end
  end

  # Mirrors HealthController.check_database/0 at a shorter timeout. Pool
  # checkout failures exit rather than raise, so both have to be caught.
  defp database_up? do
    match?({:ok, _}, Droodotfoo.Repo.query("SELECT 1", [], timeout: @db_timeout))
  rescue
    _error -> false
  catch
    :exit, _reason -> false
  end

  # PubSub liveness is the cheap honest proxy for "LiveView can work"; there is
  # no O(1) way to count connected sockets.
  defp alive?(name) do
    case Process.whereis(name) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end
end
