defmodule Droodotfoo.OG.Card do
  @moduledoc """
  The data rendered onto an Open Graph card.

  Two shapes: the site card (`site/1`) and a per-post card (`post/2`). Both pull
  from `Droodotfoo.Site` and `Droodotfoo.Core.Config` so the card always agrees
  with the site header.
  """

  alias Droodotfoo.Content.Posts.Post
  alias Droodotfoo.Site

  @enforce_keys [:key, :title, :tagline, :author, :version, :updated, :status, :nav]
  defstruct [:key, :title, :tagline, :author, :version, :updated, :status, :nav]

  @type status :: :online | :degraded

  @type t :: %__MODULE__{
          key: String.t(),
          title: String.t(),
          tagline: String.t(),
          author: String.t(),
          version: String.t(),
          updated: String.t(),
          status: status(),
          nav: [%{glyph: String.t(), label: String.t(), path: String.t()}]
        }

  @doc """
  The default card: site name, tagline, and author.
  """
  @spec site(status()) :: t()
  def site(status) do
    %__MODULE__{
      key: "site",
      title: Site.name(),
      tagline: Site.tagline(),
      author: Site.author(),
      version: Site.version(),
      updated: Site.updated_on(),
      status: status,
      nav: Site.nav()
    }
  end

  @doc """
  A post card. The title is uppercased to match the display treatment of the
  site name; the description carries through as the tagline.
  """
  @spec post(Post.t(), status()) :: t()
  def post(%Post{} = post, status) do
    %__MODULE__{
      key: "post:" <> post.slug,
      title: String.upcase(post.title),
      tagline: post.description || Site.tagline(),
      author: post.author || Site.author(),
      version: Site.version(),
      updated: post_updated(post),
      status: status,
      nav: Site.nav()
    }
  end

  # Posts carry `modified_time` only when the frontmatter sets it; otherwise the
  # publication date is the honest "updated" value for that post.
  defp post_updated(%Post{modified_time: %Date{} = modified}), do: Date.to_string(modified)
  defp post_updated(%Post{date: %Date{} = date}), do: Date.to_string(date)
  defp post_updated(%Post{}), do: Site.updated_on()
end
