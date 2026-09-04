defmodule Droodotfoo.OG.Card do
  @moduledoc """
  The data rendered onto an Open Graph card.

  Two shapes: the site card (`site/1`) and a per-post card (`post/2`). Both pull
  from `Droodotfoo.Site` and `Droodotfoo.Core.Config` so the card always agrees
  with the site header.
  """

  alias Droodotfoo.Content.Posts.Post
  alias Droodotfoo.Core.Config
  alias Droodotfoo.Site

  # Bump when the drawing code changes. Everything else that reaches the image
  # is a field on this struct, so it invalidates itself; a redesign that leaves
  # the data untouched is the one case nothing else notices.
  @render_version 1

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

  @spec render_version() :: pos_integer()
  def render_version, do: @render_version

  @doc """
  Short token covering everything visible on a card, for the image URL.

  Discord, Telegram, and Slack all proxy `og:image` through a cache of their
  own that keys on the URL and ignores ETags, so a card whose bytes change
  under a stable URL stays stale for days with no way to purge it. Carrying
  this token in the URL makes a changed card a changed URL, which every proxy
  honours because it has never seen it before.

  `:status` is excluded. It flips on a 60s timer, so including it would mint a
  new URL twice per outage and freeze whatever the status happened to be at
  crawl time into every link that was shared.
  """
  @spec token(t()) :: String.t()
  def token(%__MODULE__{} = card) do
    # Derived from the whole struct rather than a field list, so a field added
    # later is covered without anyone remembering to come back here.
    {@render_version, card |> Map.from_struct() |> Map.delete(:status)}
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 8)
  end

  @doc """
  Token for the site card. The status passed here is immaterial: `token/1`
  discards it.
  """
  @spec site_token() :: String.t()
  def site_token, do: :online |> site() |> token()

  @doc """
  Absolute, tokenized URL of the site card. Absolute because a relative
  `og:image` is resolved inconsistently across crawlers.
  """
  @spec site_image_url() :: String.t()
  def site_image_url, do: "#{Config.base_url()}/og-image.png?v=#{site_token()}"

  @doc """
  Token for a post card.
  """
  @spec post_token(Post.t()) :: String.t()
  def post_token(%Post{} = post), do: post |> post(:online) |> token()

  # Posts carry `modified_time` only when the frontmatter sets it; otherwise the
  # publication date is the honest "updated" value for that post.
  defp post_updated(%Post{modified_time: %Date{} = modified}), do: Date.to_string(modified)
  defp post_updated(%Post{date: %Date{} = date}), do: Date.to_string(date)
  defp post_updated(%Post{}), do: Site.updated_on()
end
