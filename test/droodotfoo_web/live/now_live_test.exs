defmodule DroodotfooWeb.NowLiveTest do
  use DroodotfooWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "GET /now" do
    test "renders the page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/now")

      assert html =~ "Now"
      assert html =~ "Last updated"
    end

    test "shows the Recently shipped section with upstream contributions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/now")

      assert html =~ "Recently shipped"
      assert html =~ "Upstream work merged into other projects"
      assert html =~ "contribution-type"
    end

    test "surfaces the FFmpeg and ERC-8262 wins", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/now")

      assert html =~ "FFmpeg"
      assert html =~ "ERC-8262"
    end

    test "links to the full projects list from the contributions section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/now")

      assert html =~ ~r/<a[^>]*href="\/projects"/
    end

    test "no longer includes the deprecated 'Other FOSS' paragraph", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/now")

      refute html =~ "Other FOSS:"
    end

    test "still shows the existing Running, Learning, Location sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/now")

      assert html =~ "Running"
      assert html =~ "Learning"
      assert html =~ "Location"
    end
  end
end
