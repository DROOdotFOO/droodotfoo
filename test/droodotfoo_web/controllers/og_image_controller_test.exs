defmodule DroodotfooWeb.OGImageControllerTest do
  use DroodotfooWeb.ConnCase, async: false

  alias Droodotfoo.Content.Posts

  # PNG signature followed by the IHDR chunk, whose first two fields are the
  # width and height as big-endian 32-bit integers.
  defp png_dimensions(
         <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _length::32, "IHDR", width::32, height::32,
           _rest::binary>>
       ),
       do: {width, height}

  defp png_dimensions(_other), do: :not_a_png

  describe "GET /og-image.png" do
    test "returns a 1200x630 PNG", %{conn: conn} do
      conn = get(conn, ~p"/og-image.png")

      body = response(conn, 200)

      assert {1200, 630} = png_dimensions(body)
      assert byte_size(body) > 5_000
    end

    test "serves image/png", %{conn: conn} do
      conn = get(conn, ~p"/og-image.png")

      assert ["image/png" <> _] = get_resp_header(conn, "content-type")
    end

    test "sets a public cache-control and an etag", %{conn: conn} do
      conn = get(conn, ~p"/og-image.png")

      assert ["public, max-age=" <> _ = cache_control] = get_resp_header(conn, "cache-control")
      refute cache_control =~ "immutable"

      assert [etag] = get_resp_header(conn, "etag")
      assert etag =~ ~r/^"[0-9a-f]{32}"$/
    end

    test "answers 304 when the etag matches", %{conn: conn} do
      [etag] = conn |> get(~p"/og-image.png") |> get_resp_header("etag")

      conn =
        build_conn()
        |> put_req_header("if-none-match", etag)
        |> get(~p"/og-image.png")

      assert response(conn, 304) == ""
    end

    test "is byte-identical across requests", %{conn: conn} do
      first = build_conn() |> get(~p"/og-image.png") |> response(200)
      second = conn |> get(~p"/og-image.png") |> response(200)

      assert first == second
    end

    test "does not 406 a crawler that only accepts images", %{conn: conn} do
      # The :browser pipeline's `plug :accepts, ["html"]` would reject this.
      conn =
        conn
        |> put_req_header("accept", "image/png,image/*;q=0.8")
        |> get(~p"/og-image.png")

      assert {1200, 630} = png_dimensions(response(conn, 200))
    end
  end

  describe "GET /og/:slug.png" do
    setup do
      [post | _] = Posts.list_posts()
      %{post: post}
    end

    test "returns a 1200x630 PNG for a real post", %{conn: conn, post: post} do
      conn = get(conn, ~p"/og/#{post.slug <> ".png"}")

      assert {1200, 630} = png_dimensions(response(conn, 200))
    end

    test "differs from the site card", %{conn: conn, post: post} do
      site = build_conn() |> get(~p"/og-image.png") |> response(200)
      card = conn |> get(~p"/og/#{post.slug <> ".png"}") |> response(200)

      refute site == card
    end

    test "falls back to the site card for an unknown slug", %{conn: conn} do
      # A 404 would be cached hard by crawlers, so serve something instead.
      conn = get(conn, ~p"/og/no-such-post.png")

      assert {1200, 630} = png_dimensions(response(conn, 200))
    end

    test "works without the .png suffix", %{conn: conn, post: post} do
      conn = get(conn, ~p"/og/#{post.slug}")

      assert {1200, 630} = png_dimensions(response(conn, 200))
    end
  end

  describe "when rendering fails" do
    setup do
      # Exercise the real failure path rather than a stubbed one: with the
      # renderer down, Renderer.render/1 catches the exit and the controller
      # must serve the static image instead of 500ing.
      Supervisor.terminate_child(Droodotfoo.Supervisor, Droodotfoo.OG.Renderer)
      Droodotfoo.Performance.Cache.clear(:og)

      on_exit(fn ->
        Supervisor.restart_child(Droodotfoo.Supervisor, Droodotfoo.OG.Renderer)
        Droodotfoo.Performance.Cache.clear(:og)
      end)

      :ok
    end

    test "serves the static fallback image with 200", %{conn: conn} do
      conn = get(conn, ~p"/og-image.png")

      body = response(conn, 200)

      assert {1200, 630} = png_dimensions(body)

      expected =
        :droodotfoo
        |> Application.app_dir("priv/static/images/og-image.png")
        |> File.read!()

      assert body == expected
    end

    test "caches the fallback only briefly", %{conn: conn} do
      # A long max-age would freeze a transient failure into crawler caches.
      conn = get(conn, ~p"/og-image.png")

      assert ["public, max-age=300"] = get_resp_header(conn, "cache-control")
    end

    test "post cards fall back too", %{conn: conn} do
      [post | _] = Posts.list_posts()

      assert {1200, 630} =
               conn |> get(~p"/og/#{post.slug <> ".png"}") |> response(200) |> png_dimensions()
    end
  end

  describe "post meta tags" do
    test "point at the PNG card, not the SVG pattern", %{conn: _conn} do
      [post | _] = Posts.list_posts()

      assert Posts.social_image_url(post) == "/og/#{post.slug}.png"

      # Patterns are still used for on-page decoration.
      assert Posts.pattern_url(post) =~ "/patterns/#{post.slug}"
    end
  end
end
