defmodule Droodotfoo.Wiki.Ingestion.WikipediaClientTest do
  @moduledoc """
  Characterization tests for `WikipediaClient.handle_response/1`.

  These pin the existing response-handling contract before it is migrated
  to delegate to `Droodotfoo.HttpClient.Response`. The function is pure;
  no transport stubbing required.
  """

  use ExUnit.Case, async: true

  alias Droodotfoo.Wiki.Ingestion.WikipediaClient

  describe "handle_response/1" do
    test "200 returns the body unchanged" do
      assert WikipediaClient.handle_response({:ok, %{status: 200, body: "html"}}) ==
               {:ok, "html"}
    end

    test "200 passes through a map body unchanged" do
      body = %{"title" => "Category theory", "extract" => "..."}

      assert WikipediaClient.handle_response({:ok, %{status: 200, body: body}}) ==
               {:ok, body}
    end

    test "404 maps to :not_found" do
      assert WikipediaClient.handle_response({:ok, %{status: 404}}) == {:error, :not_found}
    end

    test "other 4xx wraps in {:http_error, status}" do
      assert WikipediaClient.handle_response({:ok, %{status: 429}}) ==
               {:error, {:http_error, 429}}
    end

    test "5xx wraps in {:http_error, status}" do
      assert WikipediaClient.handle_response({:ok, %{status: 503}}) ==
               {:error, {:http_error, 503}}
    end

    test "transport error passes the reason through unchanged" do
      assert WikipediaClient.handle_response({:error, :timeout}) == {:error, :timeout}
    end
  end
end
