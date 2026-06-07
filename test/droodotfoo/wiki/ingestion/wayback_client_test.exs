defmodule Droodotfoo.Wiki.Ingestion.WaybackClientTest do
  @moduledoc """
  Characterization tests for `WaybackClient.handle_response/1`.

  These pin the snapshot-path response contract before the function body
  is migrated to delegate to `Droodotfoo.HttpClient.Response`. The
  `:request_error` wrapper on transport errors is intentional and is
  preserved through the migration.
  """

  use ExUnit.Case, async: true

  alias Droodotfoo.Wiki.Ingestion.WaybackClient

  describe "handle_response/1" do
    test "200 returns the body unchanged" do
      assert WaybackClient.handle_response({:ok, %{status: 200, body: "html"}}) ==
               {:ok, "html"}
    end

    test "404 maps to :not_found" do
      assert WaybackClient.handle_response({:ok, %{status: 404}}) == {:error, :not_found}
    end

    test "other 4xx wraps in {:http_error, status}" do
      assert WaybackClient.handle_response({:ok, %{status: 429}}) ==
               {:error, {:http_error, 429}}
    end

    test "5xx wraps in {:http_error, status}" do
      assert WaybackClient.handle_response({:ok, %{status: 502}}) ==
               {:error, {:http_error, 502}}
    end

    test "transport error wraps reason in {:request_error, reason}" do
      assert WaybackClient.handle_response({:error, :timeout}) ==
               {:error, {:request_error, :timeout}}
    end
  end
end
