defmodule Droodotfoo.Wiki.Ingestion.CommonDBTest do
  @moduledoc """
  DB-backed tests for the article-CRUD helpers on `Common`. Kept in a
  separate file from the pure tests so the latter stay sandbox-free and
  fast.
  """

  use Droodotfoo.DataCase, async: true

  alias Droodotfoo.Wiki.Content.Article
  alias Droodotfoo.Wiki.Ingestion.Common

  defp article_attrs(overrides \\ %{}) do
    Map.merge(
      %{source: :osrs, slug: "abyssal_whip", title: "Abyssal whip"},
      overrides
    )
  end

  describe "persist_article/3" do
    test ":insert with nil existing creates a new article" do
      assert {:ok, %Article{} = article} =
               Common.persist_article(:insert, nil, article_attrs())

      assert article.id != nil
      assert article.source == :osrs
      assert article.slug == "abyssal_whip"
    end

    test ":insert with a bad attr returns a changeset error" do
      assert {:error, changeset} =
               Common.persist_article(:insert, nil, article_attrs(%{source: nil}))

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:source]
    end

    test ":update applies the attrs to the existing article" do
      {:ok, article} = Common.persist_article(:insert, nil, article_attrs())

      assert {:ok, updated} =
               Common.persist_article(:update, article, %{title: "Abyssal whip (Updated)"})

      assert updated.id == article.id
      assert updated.title == "Abyssal whip (Updated)"
    end
  end

  describe "find_article/2" do
    test "returns the article when source and slug match" do
      {:ok, article} = Common.persist_article(:insert, nil, article_attrs())

      assert %Article{id: id} = Common.find_article(:osrs, "abyssal_whip")
      assert id == article.id
    end

    test "returns nil when no article matches" do
      assert Common.find_article(:osrs, "no_such_slug") == nil
    end

    test "scopes by source" do
      {:ok, _} =
        Common.persist_article(:insert, nil, article_attrs(%{source: :osrs, slug: "shared"}))

      {:ok, _} =
        Common.persist_article(
          :insert,
          nil,
          article_attrs(%{source: :wikipedia, slug: "shared", title: "Shared"})
        )

      osrs = Common.find_article(:osrs, "shared")
      wikipedia = Common.find_article(:wikipedia, "shared")

      assert osrs.source == :osrs
      assert wikipedia.source == :wikipedia
      assert osrs.id != wikipedia.id
    end
  end

  describe "list_article_slugs/2" do
    test "returns slugs for the given source up to limit" do
      for slug <- ["a", "b", "c"] do
        Common.persist_article(:insert, nil, article_attrs(%{slug: slug, title: slug}))
      end

      slugs = Common.list_article_slugs(:osrs, 10)

      assert Enum.sort(slugs) == ["a", "b", "c"]
    end

    test "applies the limit" do
      for slug <- ["a", "b", "c"] do
        Common.persist_article(:insert, nil, article_attrs(%{slug: slug, title: slug}))
      end

      assert length(Common.list_article_slugs(:osrs, 2)) == 2
    end

    test "scopes by source" do
      Common.persist_article(:insert, nil, article_attrs(%{source: :osrs, slug: "osrs_one"}))

      Common.persist_article(
        :insert,
        nil,
        article_attrs(%{source: :wikipedia, slug: "wiki_one", title: "wiki_one"})
      )

      assert Common.list_article_slugs(:osrs, 10) == ["osrs_one"]
      assert Common.list_article_slugs(:wikipedia, 10) == ["wiki_one"]
    end
  end
end
