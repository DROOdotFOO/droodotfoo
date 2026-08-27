defmodule DroodotfooWeb.Plugs.BotFilter do
  @moduledoc """
  Drops vulnerability-scanner traffic before it reaches telemetry or the router.

  Nothing here is served by PHP, so a request for a `.php` file or a WordPress
  path is always a scanner. In a sampled 100 seconds of production traffic all
  49 inbound requests were of this shape, which meant the logs held nothing but
  404s.

  This plug must sit ahead of `Plug.Telemetry` in the endpoint. Halting there
  means the start event never fires, so a scanner probe produces no log lines
  at all rather than the usual "GET /x.php" plus "Sent 404" pair.
  """

  @behaviour Plug

  import Plug.Conn

  @scanner_prefixes ~w(
    /wp-admin /wp-content /wp-includes /wp-json /wp-login /wordpress
    /phpmyadmin /pma /cgi-bin /vendor/phpunit /.env /.git /admin.php
  )

  @scanner_suffixes ~w(.php .php7 .phtml .asp .aspx .jsp .cgi)

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{request_path: path} = conn, _opts) do
    if scanner?(String.downcase(path)) do
      conn |> send_resp(404, "") |> halt()
    else
      conn
    end
  end

  defp scanner?(path) do
    String.ends_with?(path, @scanner_suffixes) or
      String.starts_with?(path, @scanner_prefixes)
  end
end
