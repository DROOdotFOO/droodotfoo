defmodule Droodotfoo.GitHub.HttpClientTest do
  @moduledoc """
  Characterization tests pinning `GitHub.HttpClient`'s response-handling
  behavior before any refactor extracts shared helpers.

  The tested functions are pure: they take an already-shaped response
  tuple and return an `{:ok, ...} | {:error, ...}` envelope. No HTTP
  transport is involved, so no stubs are needed.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Droodotfoo.GitHub.HttpClient

  describe "handle_response/2 with a 200" do
    test "applies the parser function to the body when given a function" do
      response = {:ok, %{status: 200, body: %{"name" => "raxol"}}}

      assert HttpClient.handle_response(response, & &1["name"]) == {:ok, "raxol"}
    end

    test "returns the raw body when parser is :raw" do
      response = {:ok, %{status: 200, body: "plain text"}}

      assert HttpClient.handle_response(response, :raw) == {:ok, "plain text"}
    end
  end

  describe "handle_response/2 status-to-error mapping" do
    test "401 maps to :unauthorized" do
      response = {:ok, %{status: 401}}

      assert HttpClient.handle_response(response, :raw) == {:error, :unauthorized}
    end

    test "403 maps to :rate_limited (GitHub convention)" do
      response = {:ok, %{status: 403}}

      assert HttpClient.handle_response(response, :raw) == {:error, :rate_limited}
    end

    test "404 maps to :not_found" do
      response = {:ok, %{status: 404}}

      assert HttpClient.handle_response(response, :raw) == {:error, :not_found}
    end

    test "other status codes return {:unexpected_status, status} and log an error" do
      log =
        capture_log(fn ->
          response = {:ok, %{status: 418}}

          assert HttpClient.handle_response(response, :raw) ==
                   {:error, {:unexpected_status, 418}}
        end)

      assert log =~ "418"
    end

    test "500 returns {:unexpected_status, 500} when handed in directly" do
      # rest_request retries on 5xx; handle_response itself does not.
      log =
        capture_log(fn ->
          response = {:ok, %{status: 500}}

          assert HttpClient.handle_response(response, :raw) ==
                   {:error, {:unexpected_status, 500}}
        end)

      assert log =~ "500"
    end
  end

  describe "handle_response/2 transport-level error" do
    test "passes the error reason through unchanged and logs it" do
      log =
        capture_log(fn ->
          assert HttpClient.handle_response({:error, :nxdomain}, :raw) ==
                   {:error, :nxdomain}
        end)

      assert log =~ "request failed"
    end
  end

  describe "handle_list_response/2" do
    test "empty list body returns {:error, :empty}" do
      response = {:ok, %{status: 200, body: []}}

      assert HttpClient.handle_list_response(response, & &1) == {:error, :empty}
    end

    test "non-empty list body applies parser to the first element only" do
      response = {:ok, %{status: 200, body: [%{"id" => 1}, %{"id" => 2}]}}

      assert HttpClient.handle_list_response(response, & &1["id"]) == {:ok, 1}
    end

    test "non-200 list response delegates to handle_response with :raw" do
      log =
        capture_log(fn ->
          response = {:ok, %{status: 404}}

          assert HttpClient.handle_list_response(response, & &1) == {:error, :not_found}
        end)

      # 404 path does not log; this just confirms delegation does not crash.
      _ = log
    end

    test "transport-error list response delegates to handle_response" do
      capture_log(fn ->
        assert HttpClient.handle_list_response({:error, :timeout}, & &1) ==
                 {:error, :timeout}
      end)
    end
  end
end
