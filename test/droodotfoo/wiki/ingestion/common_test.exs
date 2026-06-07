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
end
