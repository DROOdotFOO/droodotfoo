defmodule DroodotfooWeb.DroodotfooLiveTest do
  use DroodotfooWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "GET /" do
    test "renders the homepage", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "DROO.FOO"
      assert html =~ "CONNECT"
    end

    test "surfaces the SHIPPED section with the two most recent upstream contributions",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "SHIPPED"
      assert html =~ "Recent work merged upstream"
      assert html =~ "contribution-type"
    end

    test "links from SHIPPED out to the full projects page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~r/<a[^>]*href="\/projects"/
    end

    test "still lists the LATEST blog posts when posts exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "LATEST"
    end

    test "renders the updated knowsAbout structured data", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Zero-Knowledge Circuits"
      assert html =~ "ERC Standards"
    end
  end
end
