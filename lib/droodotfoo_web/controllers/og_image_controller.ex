defmodule DroodotfooWeb.OGImageController do
  @moduledoc """
  Serves the dynamic Open Graph card as PNG.

  Social crawlers refuse to render `image/svg+xml`, which is why post cards
  moved off `/patterns/:slug` and onto this controller.
  """

  use DroodotfooWeb, :controller

  require Logger

  alias Droodotfoo.OG.Image

  @cache_control "public, max-age=86400, s-maxage=604800, stale-while-revalidate=604800"

  # Deliberately short. Serving the static fallback with the normal max-age
  # would freeze a brief failure into crawler and CDN caches for a week.
  @fallback_cache_control "public, max-age=300"

  @fallback_path "images/og-image.png"

  @doc """
  Site card: `GET /og-image.png`.
  """
  def index(conn, _params), do: serve(conn, &Image.site/0)

  @doc """
  Wiki card: `GET /og/wiki.png`, used by the wiki.droo.foo layout.
  """
  def wiki(conn, _params), do: serve(conn, &Image.wiki/0)

  @doc """
  Post card: `GET /og/:slug.png`.

  The route is declared as `/og/:slug` because a route param consumes a whole
  segment, so `:slug.png` is not a valid param name. The `.png` suffix is
  stripped here.
  """
  def show(conn, %{"slug" => slug}) do
    slug = String.replace_suffix(slug, ".png", "")
    serve(conn, fn -> Image.post(slug) end)
  end

  defp serve(conn, fun) do
    case fun.() do
      {:ok, png} -> send_png(conn, png, @cache_control)
      {:error, _reason} -> send_png(conn, fallback(), @fallback_cache_control)
    end
  end

  defp send_png(conn, png, cache_control) do
    etag = etag(png)

    conn =
      conn
      |> put_resp_header("cache-control", cache_control)
      |> put_resp_header("etag", etag)

    if etag in get_req_header(conn, "if-none-match") do
      send_resp(conn, 304, "")
    else
      conn
      # nil charset: PNG is binary, so "; charset=utf-8" would be meaningless.
      |> put_resp_content_type("image/png", nil)
      |> send_resp(200, png)
    end
  end

  defp etag(png) do
    ~s("#{:crypto.hash(:md5, png) |> Base.encode16(case: :lower)}")
  end

  defp fallback do
    :droodotfoo
    |> Application.app_dir(Path.join("priv/static", @fallback_path))
    |> File.read()
    |> case do
      {:ok, png} ->
        png

      {:error, reason} ->
        Logger.error("OG fallback image unreadable: #{inspect(reason)}")
        ""
    end
  end
end
