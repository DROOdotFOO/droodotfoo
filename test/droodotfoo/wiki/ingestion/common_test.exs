defmodule Droodotfoo.Wiki.Ingestion.CommonTest do
  use ExUnit.Case, async: true

  alias Droodotfoo.Wiki.Ingestion.Common

  describe "rewrite_links/3" do
    test "applies href_fn to <a> href and src_fn to <img> src" do
      doc = Floki.parse_fragment!(~s|<a href="./wiki/foo">link</a><img src="//cdn/img.png">|)

      result =
        Common.rewrite_links(
          doc,
          fn
            "./wiki/" <> slug -> "/wikipedia/" <> slug
            other -> other
          end,
          fn
            "//" <> rest -> "https://" <> rest
            other -> other
          end
        )

      html = Floki.raw_html(result)

      assert html =~ ~s|href="/wikipedia/foo"|
      assert html =~ ~s|src="https://cdn/img.png"|
    end

    test "passes through hrefs that the transform does not match" do
      doc = Floki.parse_fragment!(~s|<a href="https://external.com">x</a>|)

      result =
        Common.rewrite_links(
          doc,
          fn
            "./wiki/" <> slug -> "/wikipedia/" <> slug
            other -> other
          end,
          & &1
        )

      assert Floki.raw_html(result) =~ ~s|href="https://external.com"|
    end

    test "leaves non-href and non-src attributes untouched" do
      doc = Floki.parse_fragment!(~s|<a href="/x" class="link" data-id="1">x</a>|)

      result = Common.rewrite_links(doc, &(&1 <> "Z"), & &1)
      html = Floki.raw_html(result)

      assert html =~ ~s|href="/xZ"|
      assert html =~ ~s|class="link"|
      assert html =~ ~s|data-id="1"|
    end

    test "leaves other tags untouched" do
      doc = Floki.parse_fragment!(~s|<a href="/x">x</a><p class="body">text</p>|)

      result = Common.rewrite_links(doc, &(&1 <> "Z"), & &1)
      html = Floki.raw_html(result)

      assert html =~ ~s|<p class="body">text</p>|
      assert html =~ ~s|href="/xZ"|
    end

    test "is a no-op when both transforms are identity" do
      doc = Floki.parse_fragment!(~s|<a href="/x">x</a><img src="/y.png">|)

      result = Common.rewrite_links(doc, & &1, & &1)

      assert result == doc
    end
  end

  describe "log_operation/3" do
    test "accepts :insert and :update with source_label and title and returns :ok" do
      assert :ok = Common.log_operation(:insert, "Wikipedia article", "Foo")
      assert :ok = Common.log_operation(:update, "OSRS article", "Bar")
      assert :ok = Common.log_operation(:insert, "VintageMachinery (Wayback)", "Drill press")
    end
  end

  describe "module_config/2" do
    defmodule FakeClient do
    end

    setup do
      Application.put_env(:droodotfoo, FakeClient, base_url: "https://x", rate_limit_ms: 250)
      on_exit(fn -> Application.delete_env(:droodotfoo, FakeClient) end)
    end

    test "returns the configured value for a known key" do
      assert Common.module_config(FakeClient, :base_url) == "https://x"
      assert Common.module_config(FakeClient, :rate_limit_ms) == 250
    end

    test "returns nil for an unconfigured key under a configured module" do
      assert Common.module_config(FakeClient, :missing_key) == nil
    end

    test "returns nil for an unconfigured module" do
      assert Common.module_config(Droodotfoo.Wiki.Ingestion.CommonTest.NotARealModule, :anything) ==
               nil
    end
  end

  describe "hash_content/1" do
    test "delegates to Droodotfoo.Hash.sha256_hex" do
      assert Common.hash_content("hello") == Droodotfoo.Hash.sha256_hex("hello")
    end

    test "produces a 64-character lowercase hex string" do
      hash = Common.hash_content("anything")

      assert String.length(hash) == 64
      assert hash =~ ~r/\A[0-9a-f]{64}\z/
    end
  end

  describe "extract_text/2" do
    test "strips HTML tags and returns the visible text" do
      html = "<p>Hello <strong>world</strong></p>"

      assert Common.extract_text(html) == "Hello world"
    end

    test "collapses runs of whitespace to a single space" do
      html = "<p>a   b\n\nc\td</p>"

      assert Common.extract_text(html) == "a b c d"
    end

    test "truncates to max_length" do
      html = "<p>" <> String.duplicate("x", 100) <> "</p>"

      assert Common.extract_text(html, 10) == String.duplicate("x", 10)
    end
  end

  describe "aggregate_stats/1" do
    test "counts results by status atom" do
      results = %{
        "a" => {:created, %{}},
        "b" => {:updated, %{}},
        "c" => {:unchanged, %{}},
        "d" => {:created, %{}},
        "e" => {:error, :timeout}
      }

      assert Common.aggregate_stats(results) ==
               %{created: 2, updated: 1, unchanged: 1, errors: 1}
    end

    test "returns all zeros for an empty input" do
      assert Common.aggregate_stats(%{}) ==
               %{created: 0, updated: 0, unchanged: 0, errors: 0}
    end
  end

  describe "upstream_url/2" do
    test "concatenates base and slug for a simple slug" do
      assert Common.upstream_url("https://x/wiki/", "Foo_bar") == "https://x/wiki/Foo_bar"
    end

    test "URI-encodes unsafe characters in the slug" do
      assert Common.upstream_url("https://x/", "a b/c") == "https://x/a%20b%2Fc"
    end
  end

  describe "humanize_slug/1" do
    test "replaces underscores with spaces and capitalizes each word" do
      assert Common.humanize_slug("hello_world") == "Hello World"
    end

    test "replaces hyphens with spaces and capitalizes each word" do
      assert Common.humanize_slug("some-page-title") == "Some Page Title"
    end

    test "handles mixed underscores and hyphens" do
      assert Common.humanize_slug("foo-bar_baz") == "Foo Bar Baz"
    end
  end

  describe "operation_result/1" do
    test ":insert maps to :created" do
      assert Common.operation_result(:insert) == :created
    end

    test ":update maps to :updated" do
      assert Common.operation_result(:update) == :updated
    end
  end

  describe "filter_out_all/2" do
    test "removes elements matching each selector" do
      doc = Floki.parse_fragment!(~s|<div><script>x</script><p>keep</p><style>y</style></div>|)

      result = Common.filter_out_all(doc, ["script", "style"])
      html = Floki.raw_html(result)

      refute html =~ "<script>"
      refute html =~ "<style>"
      assert html =~ "<p>keep</p>"
    end

    test "returns the doc unchanged when no selectors match" do
      doc = Floki.parse_fragment!(~s|<div><p>keep</p></div>|)

      assert Common.filter_out_all(doc, ["script", ".sidebar"]) == doc
    end
  end

  describe "clean_html/2" do
    test "applies the transform to the parsed doc and round-trips through raw_html" do
      result =
        Common.clean_html("<p>hi</p>", fn doc ->
          Common.filter_out_all(doc, ["script"])
        end)

      assert result =~ "<p>hi</p>"
    end

    test "returns the original input unchanged when Floki cannot parse" do
      # Floki actually parses almost anything; binary garbage that crashes parsing.
      bad = <<0xFF, 0xFE, 0xFD>>

      assert Common.clean_html(bad, fn doc -> doc end) == bad
    end
  end

  describe "process_pages_sequential/2" do
    test "calls process_fn on each item and returns a map keyed by item" do
      result = Common.process_pages_sequential([1, 2, 3], fn x -> x * 10 end)

      assert result == %{1 => 10, 2 => 20, 3 => 30}
    end

    test "returns an empty map for an empty input" do
      assert Common.process_pages_sequential([], fn _ -> :ok end) == %{}
    end
  end

  describe "process_pages_concurrent/3" do
    test "calls process_fn on each item and returns a map keyed by item" do
      result =
        Common.process_pages_concurrent([1, 2, 3], fn x -> x * 10 end, max_concurrency: 2)

      assert result == %{1 => 10, 2 => 20, 3 => 30}
    end

    test "captures per-item timeouts as {:error, :timeout} rather than crashing the caller" do
      result =
        Common.process_pages_concurrent(
          [:slow],
          fn _ -> Process.sleep(200) end,
          max_concurrency: 1,
          timeout: 25
        )

      assert %{slow: {:error, :timeout}} = result
    end
  end
end
