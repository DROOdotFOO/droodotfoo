defmodule Droodotfoo.Site do
  @moduledoc """
  Site-wide branding: name, tagline, author, and the primary nav.

  Single source for values that previously lived as duplicated string literals
  in the root layout, the header component, and the JSON-LD builder. The
  Open Graph card renders from the same values the page does, so the two
  cannot drift.
  """

  alias Droodotfoo.Core.Config

  @name "DROO.FOO"
  @tagline "Engineer building his Gundam"
  @author "DROO"
  @author_url "https://github.com/DROOdotFOO/droodotfoo"

  # Order matches the OG card and the mobile nav. The glyph is decorative and
  # is rendered as part of the label on the card.
  @nav [
    %{glyph: "/", label: "Home", path: "/"},
    %{glyph: "~", label: "About", path: "/about"},
    %{glyph: "*", label: "Now", path: "/now"},
    %{glyph: "#", label: "Projects", path: "/projects"},
    %{glyph: ">", label: "Writing", path: "/posts"},
    %{glyph: "+", label: "Sitemap", path: "/sitemap"},
    %{glyph: "@", label: "Contact", path: "/contact"}
  ]

  @wiki_name "WIKI.DROO.FOO"
  @wiki_tagline "Federated wiki mirror aggregating OSRS Wiki, nLab mathematics, Wikipedia, and more"

  # Mirrors the dot-separated nav in DroodotfooWeb.Wiki.Layouts.site_nav/1.
  # Glyphs are decorative, as on the main nav.
  @wiki_nav [
    %{glyph: "/", label: "Home", path: "/"},
    %{glyph: "?", label: "Search", path: "/search"},
    %{glyph: "#", label: "OSRS", path: "/osrs"},
    %{glyph: "~", label: "nLab", path: "/nlab"},
    %{glyph: "@", label: "droo.foo", path: "https://droo.foo"}
  ]

  @spec name() :: String.t()
  def name, do: @name

  @spec wiki_name() :: String.t()
  def wiki_name, do: @wiki_name

  @spec wiki_tagline() :: String.t()
  def wiki_tagline, do: @wiki_tagline

  @spec wiki_nav() :: [%{glyph: String.t(), label: String.t(), path: String.t()}]
  def wiki_nav, do: @wiki_nav

  @spec tagline() :: String.t()
  def tagline, do: @tagline

  @spec author() :: String.t()
  def author, do: @author

  @spec author_url() :: String.t()
  def author_url, do: @author_url

  @spec nav() :: [%{glyph: String.t(), label: String.t(), path: String.t()}]
  def nav, do: @nav

  @doc """
  Application version as a string. `Application.spec/2` returns a charlist.
  """
  @spec version() :: String.t()
  def version, do: :droodotfoo |> Application.spec(:vsn) |> List.to_string()

  @doc """
  Release date shown as "Updated", as an ISO date string.
  """
  @spec updated_on() :: String.t()
  def updated_on, do: Config.released_on() |> Date.to_string()
end
