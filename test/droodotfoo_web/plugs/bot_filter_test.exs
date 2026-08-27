defmodule DroodotfooWeb.Plugs.BotFilterTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias DroodotfooWeb.Plugs.BotFilter

  defp run(path) do
    :get |> conn(path) |> BotFilter.call(BotFilter.init([]))
  end

  describe "scanner paths" do
    test "halts with 404 on PHP probes" do
      for path <- ["/xmlrpc.php", "/wp-blog.php", "/a4.php", "/index.phtml"] do
        conn = run(path)

        assert conn.halted, "expected #{path} to halt"
        assert conn.status == 404
      end
    end

    test "halts on WordPress and admin tool prefixes" do
      for path <- [
            "/wp-admin/setup-config.php",
            "/wp-content/uploads/panel.php",
            "/phpmyadmin/index.html",
            "/.env",
            "/.git/config"
          ] do
        conn = run(path)

        assert conn.halted, "expected #{path} to halt"
        assert conn.status == 404
      end
    end

    test "matches regardless of case" do
      conn = run("/WP-ADMIN/Setup-Config.PHP")

      assert conn.halted
      assert conn.status == 404
    end
  end

  describe "legitimate paths" do
    test "passes real routes through untouched" do
      for path <- ["/", "/about", "/posts/some-slug", "/resume", "/health"] do
        conn = run(path)

        refute conn.halted, "expected #{path} to pass"
        assert is_nil(conn.status)
      end
    end

    test "does not swallow well-known paths" do
      conn = run("/.well-known/security.txt")

      refute conn.halted
    end
  end
end
