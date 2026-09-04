defmodule Droodotfoo.OG.FontMetrics do
  @moduledoc """
  Minimal OpenType metric reader.

  Exists so a test can assert that the vendored font still matches the numbers
  `Droodotfoo.OG.Layout` is built on. The card positions every glyph by
  arithmetic on a single advance width, so a font upgrade that changed the
  advance or the em size would silently shift the entire layout.

  Reads only what that check needs; this is not a general font parser.
  """

  @type metrics :: %{
          units_per_em: pos_integer(),
          advance_width: pos_integer(),
          number_of_h_metrics: pos_integer()
        }

  @doc """
  Reads `head.unitsPerEm`, the first `hmtx` advance, and
  `hhea.numberOfHMetrics` from an OTF or TTF file.

  `number_of_h_metrics` of 2 confirms the font is genuinely monospaced: one
  advance applies to every glyph.
  """
  @spec read(Path.t()) :: {:ok, metrics()} | {:error, term()}
  def read(path) do
    with {:ok, data} <- File.read(path),
         {:ok, tables} <- table_directory(data),
         {:ok, units_per_em} <- units_per_em(data, tables),
         {:ok, number_of_h_metrics} <- number_of_h_metrics(data, tables),
         {:ok, advance_width} <- advance_width(data, tables) do
      {:ok,
       %{
         units_per_em: units_per_em,
         advance_width: advance_width,
         number_of_h_metrics: number_of_h_metrics
       }}
    end
  end

  @doc """
  Advance as a fraction of the em square, which is what `Layout.advance_ratio/0`
  encodes.
  """
  @spec advance_ratio(metrics()) :: float()
  def advance_ratio(%{advance_width: advance, units_per_em: upm}), do: advance / upm

  defp table_directory(<<_sfnt::32, num_tables::16, _rest::binary>> = data) do
    tables =
      for index <- 0..(num_tables - 1), into: %{} do
        <<tag::binary-4, _checksum::32, offset::32, length::32>> =
          binary_part(data, 12 + index * 16, 16)

        {tag, {offset, length}}
      end

    {:ok, tables}
  end

  defp table_directory(_data), do: {:error, :not_a_font}

  defp units_per_em(data, tables) do
    with {:ok, {offset, _length}} <- fetch_table(tables, "head") do
      <<upm::16>> = binary_part(data, offset + 18, 2)
      {:ok, upm}
    end
  end

  defp number_of_h_metrics(data, tables) do
    with {:ok, {offset, _length}} <- fetch_table(tables, "hhea") do
      <<count::16>> = binary_part(data, offset + 34, 2)
      {:ok, count}
    end
  end

  defp advance_width(data, tables) do
    with {:ok, {offset, _length}} <- fetch_table(tables, "hmtx") do
      <<advance::16>> = binary_part(data, offset, 2)
      {:ok, advance}
    end
  end

  defp fetch_table(tables, tag) do
    case Map.fetch(tables, tag) do
      {:ok, entry} -> {:ok, entry}
      :error -> {:error, {:missing_table, tag}}
    end
  end
end
