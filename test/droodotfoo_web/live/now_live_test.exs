defmodule DroodotfooWeb.NowLiveTest do
  use DroodotfooWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "GET /now" do
    test "renders the page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/now")

      assert html =~ "Now"
      assert html =~ "Last updated"
    end

    test "no longer shows the Recently shipped section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/now")

      refute html =~ "Recently shipped"
      refute html =~ "Upstream work merged into other projects"
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
