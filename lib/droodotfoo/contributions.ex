defmodule Droodotfoo.Contributions do
  @moduledoc """
  Upstream open-source contributions (work merged into other projects).

  Reads `upstream_contributions` from `ResumeData` and normalizes into
  `%Contribution{}` structs. Sibling to `Droodotfoo.Projects` (which handles
  maintained projects).
  """

  alias Droodotfoo.Resume.ResumeData

  defstruct [:project, :title, :description, :url, :type, :date, :tags]

  @type type :: :merged | :standard | :extension | :docs

  @type t :: %__MODULE__{
          project: String.t(),
          title: String.t(),
          description: String.t(),
          url: String.t(),
          type: type(),
          date: String.t(),
          tags: list(String.t())
        }

  @doc "All contributions, newest first."
  @spec all() :: list(t())
  def all do
    ResumeData.get_resume_data()
    |> Map.get(:upstream_contributions, [])
    |> Enum.map(&build/1)
    |> Enum.sort_by(& &1.date, :desc)
  end

  @doc "Most recent `n` contributions."
  @spec recent(pos_integer()) :: list(t())
  def recent(n) when is_integer(n) and n > 0 do
    all() |> Enum.take(n)
  end

  @doc "Short label for the contribution type, suitable for a badge."
  @spec type_label(type()) :: String.t()
  def type_label(:merged), do: "merged"
  def type_label(:standard), do: "draft ERC"
  def type_label(:extension), do: "extension"
  def type_label(:docs), do: "docs"
  def type_label(_), do: "shipped"

  defp build(raw) do
    %__MODULE__{
      project: raw[:project],
      title: raw[:title],
      description: raw[:description],
      url: raw[:url],
      type: parse_type(raw[:type]),
      date: raw[:date],
      tags: raw[:tags] || []
    }
  end

  defp parse_type("merged"), do: :merged
  defp parse_type("standard"), do: :standard
  defp parse_type("extension"), do: :extension
  defp parse_type("docs"), do: :docs
  defp parse_type(_), do: :merged
end
