defmodule Droodotfoo.GitHub.HttpClient do
  @moduledoc """
  HTTP client for GitHub API with retry logic and status handling.
  """

  require Logger

  alias Droodotfoo.ErrorSanitizer
  alias Droodotfoo.HttpClient.Response

  @github_rest_api_url "https://api.github.com"
  @github_graphql_url "https://api.github.com/graphql"
  @max_retries 3

  @status_map %{401 => :unauthorized, 403 => :rate_limited, 404 => :not_found}
  @response_opts [status_map: @status_map, log_prefix: "GitHub API"]

  # Type definitions

  @type http_response :: {:ok, Req.Response.t()} | {:error, term()}
  @type api_result :: {:ok, term()} | {:error, api_error()}
  @type api_error ::
          :unauthorized | :rate_limited | :not_found | :no_token | :request_failed | term()
  @type parser :: (term() -> term()) | :raw
  @type request_opts :: [retry_count: non_neg_integer()]

  @doc """
  Make a REST API request with retry logic.
  """
  @spec rest_request(String.t(), request_opts()) :: http_response()
  def rest_request(path, opts \\ []) do
    url = @github_rest_api_url <> path
    headers = build_rest_headers()
    retry_count = Keyword.get(opts, :retry_count, 0)

    case Req.get(url, headers: headers) do
      {:ok, %{status: status}}
      when status in [500, 502, 503, 504] and retry_count < @max_retries ->
        retry_with_backoff(
          fn -> rest_request(path, retry_count: retry_count + 1) end,
          retry_count,
          status
        )

      response ->
        response
    end
  rescue
    error ->
      handle_request_error(
        error,
        fn -> rest_request(path, retry_count: opts[:retry_count] || 0 + 1) end,
        opts[:retry_count] || 0
      )
  end

  @doc """
  Make a GraphQL API request.
  """
  @spec graphql_request(String.t()) :: {:ok, String.t()} | {:error, term()}
  def graphql_request(query) do
    case github_token() do
      token when token in [nil, ""] ->
        {:error, :no_token}

      token ->
        do_graphql_request(query, token)
    end
  end

  @doc """
  Handle HTTP response status codes uniformly.
  """
  @spec handle_response(http_response(), parser()) :: api_result()
  def handle_response(response, parser),
    do: Response.handle(response, parser, @response_opts)

  @doc """
  Handle empty list response specifically.
  """
  @spec handle_list_response(http_response(), parser()) :: api_result()
  def handle_list_response(response, parser),
    do: Response.handle_list(response, parser, @response_opts)

  # Private

  defp build_rest_headers do
    base = [
      {"accept", "application/vnd.github.v3+json"},
      {"user-agent", "droodotfoo"}
    ]

    case github_token() do
      token when token in [nil, ""] -> base
      token -> [{"authorization", "Bearer #{token}"} | base]
    end
  end

  defp do_graphql_request(query, token) do
    headers = [
      {~c"Content-Type", ~c"application/json"},
      {~c"User-Agent", ~c"droo.foo-terminal"},
      {~c"Authorization", String.to_charlist("Bearer #{token}")}
    ]

    body = Jason.encode!(%{query: query})

    case :httpc.request(
           :post,
           {String.to_charlist(@github_graphql_url), headers, ~c"application/json",
            String.to_charlist(body)},
           [],
           []
         ) do
      {:ok, {{_, 200, _}, _headers, response_body}} ->
        {:ok, List.to_string(response_body)}

      {:ok, {{_, status, _}, _headers, _response_body}} ->
        Logger.error("GitHub GraphQL API returned status #{status}")
        {:error, "GitHub API error: #{status}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{ErrorSanitizer.sanitize(reason)}"}
    end
  end

  defp github_token do
    case System.get_env("GITHUB_TOKEN") do
      token when token not in [nil, ""] -> token
      _ -> Application.get_env(:droodotfoo, :github_token)
    end
  end

  defp retry_with_backoff(retry_fn, retry_count, status) do
    backoff_ms = (:math.pow(2, retry_count) * 1000) |> round()

    Logger.warning(
      "GitHub API returned #{status}, retrying in #{backoff_ms}ms (attempt #{retry_count + 1}/#{@max_retries})"
    )

    Process.sleep(backoff_ms)
    retry_fn.()
  end

  defp handle_request_error(error, retry_fn, retry_count) do
    if retry_count < @max_retries do
      backoff_ms = (:math.pow(2, retry_count) * 1000) |> round()

      Logger.warning(
        "GitHub request failed: #{inspect(error)}, retrying in #{backoff_ms}ms (attempt #{retry_count + 1}/#{@max_retries})"
      )

      Process.sleep(backoff_ms)
      retry_fn.()
    else
      Logger.error("GitHub request failed after #{retry_count} retries: #{inspect(error)}")
      {:error, :request_failed}
    end
  end
end
