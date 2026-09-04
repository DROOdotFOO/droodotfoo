defmodule Droodotfoo.OG.Image do
  @moduledoc """
  Cached Open Graph card PNGs.

  Thin wrapper over `Performance.Cache`, in the shape of
  `Droodotfoo.Content.PatternCache`, so it needs no supervision entry of its own.

  Cards are deterministic given their inputs, so the cache key carries
  everything that appears on the image: the card identity, the app version, the
  release date, and the current status. `Card.render_version/0` is bumped by
  hand when the card design changes, which invalidates every cached PNG without
  waiting for a TTL, and moves the URL token along with it.

  In practice there are only a handful of distinct cards and the key changes at
  most once per deploy, so entries are written once and read forever.
  """

  require Logger

  alias Droodotfoo.Content.Posts
  alias Droodotfoo.OG.{Card, Renderer, Status}
  alias Droodotfoo.Performance.Cache

  @namespace :og
  @ttl :timer.hours(24)

  @doc """
  PNG for the site card.
  """
  @spec site() :: {:ok, binary()} | {:error, term()}
  def site, do: fetch(Card.site(Status.get()))

  @doc """
  PNG for the wiki card.
  """
  @spec wiki() :: {:ok, binary()} | {:error, term()}
  def wiki, do: fetch(Card.wiki(Status.get()))

  @doc """
  PNG for a post card. Falls back to the site card when the slug is unknown, so
  a stale link still unfurls with something rather than a 404 that crawlers
  cache aggressively.
  """
  @spec post(String.t()) :: {:ok, binary()} | {:error, term()}
  def post(slug) do
    case Posts.get_post(slug) do
      {:ok, post} -> fetch(Card.post(post, Status.get()))
      {:error, :not_found} -> site()
    end
  end

  @doc """
  Renders every card into the cache. Called off the request path at boot so a
  crawler never pays for a render.
  """
  @spec warm() :: :ok
  def warm do
    if Renderer.available?() do
      status = Status.get()

      cards =
        [Card.site(status), Card.wiki(status)] ++
          Enum.map(Posts.list_posts(), &Card.post(&1, status))

      results = Enum.map(cards, &fetch/1)
      failed = Enum.count(results, &match?({:error, _}, &1))

      Logger.info("OG cards warmed: #{length(results) - failed}/#{length(results)}")
    else
      Logger.warning("OG renderer unavailable, skipping card warm-up")
    end

    :ok
  end

  defp fetch(%Card{} = card) do
    key = cache_key(card)

    case Cache.get(@namespace, key) do
      {:ok, png} ->
        {:ok, png}

      :error ->
        with {:ok, png} <- Renderer.render(card) do
          Cache.put(@namespace, key, png, ttl: @ttl)
          {:ok, png}
        end
    end
  end

  defp cache_key(%Card{} = card) do
    {card.key, Card.render_version(), card.version, card.updated, card.status}
  end
end
