defmodule DroodotfooWeb.ProjectsLiveTest do
  use DroodotfooWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "GET /projects" do
    test "renders the page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/projects")

      assert html =~ "Projects"
    end

    test "shows both the Upstream and Maintained sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/projects")

      assert html =~ "Upstream contributions"
      assert html =~ "Maintained projects"
      assert html =~ "Work merged into other projects"
      assert html =~ "Open source I work on"
    end

    test "renders every known upstream contribution", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/projects")

      for project <- ["Ethereum ERCs", "Dappnode", "Zed"] do
        assert html =~ project, "expected #{project} in /projects HTML"
      end
    end

    test "lists FFmpeg and aztec-noir as maintained projects", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/projects")

      assert html =~ "FFmpeg"
      assert html =~ "aztec-noir"
    end

    test "renders contribution-type badges with bracket pseudo-elements available", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/projects")

      # We render at least one of each badge class so CSS ::before/::after wraps them
      assert html =~ "contribution-type status-active"
      assert html =~ "contribution-type status-done"
    end

    test "still renders the maintained projects grid", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/projects")

      assert html =~ "projects-grid"
      assert html =~ "project-card"
    end
  end
end
