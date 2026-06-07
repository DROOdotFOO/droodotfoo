defmodule Droodotfoo.HttpClient.Response do
  @moduledoc """
  Generic HTTP-response envelope handling shared across API clients.

  Each caller supplies its own status-to-error mapping. The reason this
  is a per-caller map and not a hard-coded one is that conventions vary
  by service: GitHub maps 403 to `:rate_limited`, while a service that
  uses 403 strictly for permission denial maps it to `:forbidden`.

  ## Usage

      alias Droodotfoo.HttpClient.Response

      @status_map %{401 => :unauthorized, 403 => :rate_limited, 404 => :not_found}
      @opts [status_map: @status_map, log_prefix: "GitHub API"]

      def handle_response(response, parser) do
        Response.handle(response, parser, @opts)
      end
  """

  require Logger

  alias Droodotfoo.ErrorSanitizer

  @type response :: {:ok, %{status: integer(), body: term()}} | {:error, term()}
  @type parser :: (term() -> term()) | :raw
  @type opts :: [status_map: %{integer() => atom()}, log_prefix: String.t()]
  @type result :: {:ok, term()} | {:error, term()}

  @doc """
  Handle a single-resource response.

  - 200 with a parser function: applies the parser to the body.
  - 200 with `:raw`: returns the body unchanged.
  - Any other status: looks up the status in `:status_map`. If found, returns
    `{:error, atom}`. Otherwise logs and returns `{:error, {:unexpected_status, status}}`.
  - Transport error: logs and returns `{:error, reason}` with the reason
    passed through unchanged.
  """
  @spec handle(response(), parser(), opts()) :: result()
  def handle(response, parser, opts \\ [])

  def handle({:ok, %{status: 200, body: body}}, parser, _opts) when is_function(parser, 1) do
    {:ok, parser.(body)}
  end

  def handle({:ok, %{status: 200, body: body}}, :raw, _opts) do
    {:ok, body}
  end

  def handle({:ok, %{status: status}}, _parser, opts) do
    case Map.fetch(status_map(opts), status) do
      {:ok, atom} ->
        {:error, atom}

      :error ->
        Logger.error("#{log_prefix(opts)} returned unexpected status: #{status}")
        {:error, {:unexpected_status, status}}
    end
  end

  def handle({:error, reason}, _parser, opts) do
    Logger.error("#{log_prefix(opts)} request failed: #{ErrorSanitizer.sanitize(reason)}")
    {:error, reason}
  end

  @doc """
  Handle a list-resource response.

  - 200 with an empty list: `{:error, :empty}`.
  - 200 with a non-empty list: applies the parser to the first element.
  - Anything else: delegates to `handle/3` with `:raw`.
  """
  @spec handle_list(response(), parser(), opts()) :: result()
  def handle_list({:ok, %{status: 200, body: []}}, _parser, _opts), do: {:error, :empty}

  def handle_list({:ok, %{status: 200, body: [first | _]}}, parser, _opts)
      when is_function(parser, 1),
      do: {:ok, parser.(first)}

  def handle_list(response, _parser, opts), do: handle(response, :raw, opts)

  defp status_map(opts), do: Keyword.get(opts, :status_map, %{})
  defp log_prefix(opts), do: Keyword.get(opts, :log_prefix, "HTTP")
end
