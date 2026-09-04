defmodule Droodotfoo.OG.Layout do
  @moduledoc """
  Geometry and text metrics for the 1200x630 Open Graph card.

  Every constant here was measured from the design reference at 1x rather than
  derived from CSS, because the card is drawn as SVG with explicit baselines
  instead of laid out by a browser.

  Text metrics rely on Monaspace Argon being genuinely monospaced: the font
  reports `numberOfHMetrics = 2` and a single advance of 1240/2000 em, so every
  glyph is exactly `0.62 * font_size` wide. `font_metrics_test.exs` asserts this
  against the vendored file so a font upgrade cannot silently shift the layout.
  """

  # -- Canvas -----------------------------------------------------------------

  @width 1200
  @height 630

  @bg "#0a0a0a"
  @fg "#e0e0e0"
  @muted "#999999"
  @online "#00ff41"
  @degraded "#ffb000"
  @logo_fill "#FD4F00"

  @border 2

  # -- Frame ------------------------------------------------------------------

  @frame_left 60
  @frame_top 60
  @frame_right 1140
  @frame_bottom 570

  # Left cell's right border; the 340px right column starts after it.
  @divider_x 796

  @footer_border_y 501

  # -- Left cell --------------------------------------------------------------

  @left_x 106
  @left_max_width 646

  @title_size 120
  @title_letter_spacing -0.02
  # The title block is top-aligned in the cell, so what stays fixed as the
  # font shrinks is the cap top, not the baseline. At the design size this
  # reproduces the measured baseline of 192.6.
  @title_cap_top 105
  @title_line_height 0.95
  # Design margin between the title block and the tagline.
  @title_margin 24
  @tagline_size 36

  @cap_height 0.73
  # Space below the baseline occupied by descenders, in em.
  @descender 0.25

  @author_baseline 453.0
  @author_size 24
  # Gap between the "Author" advance box and the start of the author name.
  @author_gap 22
  @author_underline_offset 7

  # -- Right column -----------------------------------------------------------

  @right_label_x 822
  @right_value_x 1114
  @right_size 22
  @right_baselines [139.6, 286.6, 434.6]
  @right_divider_ys [207, 354]

  @status_dot_radius 6.75
  @status_dot_rise 5.5
  @status_logo_height 28
  @status_logo_gap 14
  # Phoenix mark, viewBox "0 0 71 48".
  @logo_view_w 71
  @logo_view_h 48

  # -- Footer -----------------------------------------------------------------

  @footer_x 106
  @footer_right 1094
  @footer_baseline 542.1
  @footer_size 24

  # -- Text metrics -----------------------------------------------------------

  @advance_ratio 0.62

  @title_sizes [120, 96, 80, 72, 64, 56, 48, 44, 40]
  @description_sizes [36, 32, 28]

  def width, do: @width
  def height, do: @height

  def bg, do: @bg
  def fg, do: @fg
  def muted, do: @muted
  def online_color, do: @online
  def degraded_color, do: @degraded
  def logo_fill, do: @logo_fill
  def border, do: @border

  def frame, do: %{left: @frame_left, top: @frame_top, right: @frame_right, bottom: @frame_bottom}
  def divider_x, do: @divider_x
  def footer_border_y, do: @footer_border_y

  def left_x, do: @left_x
  def left_max_width, do: @left_max_width
  def title_size, do: @title_size
  def title_letter_spacing, do: @title_letter_spacing
  def title_line_height, do: @title_line_height
  def tagline_size, do: @tagline_size
  def cap_height, do: @cap_height

  @doc """
  Baseline of the title's first line. The title is top-aligned, so a smaller
  font keeps its cap top on the same line rather than sliding down the cell.
  """
  @spec title_baseline(number()) :: float()
  def title_baseline(font_size), do: @title_cap_top + @cap_height * font_size

  @doc """
  Gap from the title's last baseline to the tagline's first baseline: the
  title's descender space, the design margin, then the tagline's cap height.
  """
  @spec tagline_gap(number(), number()) :: float()
  def tagline_gap(title_size, tagline_size) do
    title_size * @descender + @title_margin + tagline_size * @cap_height
  end

  def author_baseline, do: @author_baseline
  def author_size, do: @author_size
  def author_gap, do: @author_gap
  def author_underline_offset, do: @author_underline_offset

  def right_label_x, do: @right_label_x
  def right_value_x, do: @right_value_x
  def right_size, do: @right_size
  def right_baselines, do: @right_baselines
  def right_divider_ys, do: @right_divider_ys

  def status_dot_radius, do: @status_dot_radius
  def status_dot_rise, do: @status_dot_rise
  def status_logo_height, do: @status_logo_height
  def status_logo_gap, do: @status_logo_gap

  @doc "Rendered width of the logo at `status_logo_height/0`, preserving aspect."
  def status_logo_width, do: @status_logo_height * @logo_view_w / @logo_view_h

  def footer_x, do: @footer_x
  def footer_right, do: @footer_right
  def footer_baseline, do: @footer_baseline
  def footer_size, do: @footer_size

  def advance_ratio, do: @advance_ratio
  def title_sizes, do: @title_sizes
  def description_sizes, do: @description_sizes

  @doc """
  Per-character advance in pixels, including optional letter-spacing expressed
  in em (the title uses -0.02em).
  """
  @spec advance(number(), number()) :: float()
  def advance(font_size, letter_spacing_em \\ 0.0) do
    font_size * (@advance_ratio + letter_spacing_em)
  end

  @doc """
  Width of `text` in pixels. Counts graphemes, so combining marks do not
  over-count.
  """
  @spec text_width(String.t(), number(), number()) :: float()
  def text_width(text, font_size, letter_spacing_em \\ 0.0) do
    length(String.graphemes(text)) * advance(font_size, letter_spacing_em)
  end

  @doc """
  Number of whole characters that fit in `max_width` at `font_size`.
  """
  @spec chars_per_line(number(), number(), number()) :: non_neg_integer()
  def chars_per_line(max_width, font_size, letter_spacing_em \\ 0.0) do
    max_width |> Kernel./(advance(font_size, letter_spacing_em)) |> trunc()
  end

  @doc """
  Greedy word wrap. Returns `{:ok, lines}` when the text fits in `max_lines`,
  or `:too_long` when it does not.

  A single word longer than the line is hard-split rather than overflowing.
  """
  @spec wrap(String.t(), number(), number(), pos_integer(), number()) ::
          {:ok, [String.t()]} | :too_long
  def wrap(text, max_width, font_size, max_lines, letter_spacing_em \\ 0.0) do
    per_line = chars_per_line(max_width, font_size, letter_spacing_em)

    if per_line < 1 do
      :too_long
    else
      text
      |> String.split(~r/\s+/, trim: true)
      |> Enum.flat_map(&hard_split(&1, per_line))
      |> Enum.reduce([], &greedy_fill(&1, &2, per_line))
      |> Enum.reverse()
      |> check_line_count(max_lines)
    end
  end

  defp greedy_fill(word, [], _per_line), do: [word]

  defp greedy_fill(word, [current | rest] = lines, per_line) do
    candidate = current <> " " <> word

    if String.length(candidate) <= per_line do
      [candidate | rest]
    else
      [word | lines]
    end
  end

  defp check_line_count(lines, max_lines) when length(lines) <= max_lines, do: {:ok, lines}
  defp check_line_count(_lines, _max_lines), do: :too_long

  defp hard_split(word, per_line) do
    if String.length(word) <= per_line do
      [word]
    else
      word
      |> String.graphemes()
      |> Enum.chunk_every(per_line)
      |> Enum.map(&Enum.join/1)
    end
  end

  @doc """
  Largest size from `sizes` at which `text` wraps into at most `max_lines`.

  Returns `{font_size, lines}`. Sizes that would fit only by hard-splitting a
  word are passed over first: "WIKI.DROO.FOO" broken as "WIKI.DRO" / "O.FOO"
  reads worse than the same title one step smaller and whole. A split is still
  taken over nothing if no size avoids it.

  If even the smallest size overflows, the text is wrapped at that size and
  truncated with an ellipsis on the last line, so a card is always produced.
  """
  @spec fit(String.t(), [number()], number(), pos_integer(), number()) ::
          {number(), [String.t()]}
  def fit(text, sizes, max_width, max_lines, letter_spacing_em \\ 0.0) do
    longest = longest_word(text)

    whole_word_sizes =
      Enum.filter(sizes, fn size ->
        longest <= chars_per_line(max_width, size, letter_spacing_em)
      end)

    first_fit(text, whole_word_sizes, max_width, max_lines, letter_spacing_em) ||
      first_fit(text, sizes, max_width, max_lines, letter_spacing_em) ||
      truncate_at(text, List.last(sizes), max_width, max_lines, letter_spacing_em)
  end

  defp first_fit(text, sizes, max_width, max_lines, letter_spacing_em) do
    Enum.find_value(sizes, fn size ->
      case wrap(text, max_width, size, max_lines, letter_spacing_em) do
        {:ok, lines} -> {size, lines}
        :too_long -> nil
      end
    end)
  end

  defp longest_word(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&String.length/1)
    |> Enum.max(fn -> 0 end)
  end

  defp truncate_at(text, size, max_width, max_lines, letter_spacing_em) do
    per_line = chars_per_line(max_width, size, letter_spacing_em)

    lines =
      text
      |> String.split(~r/\s+/, trim: true)
      |> Enum.flat_map(&hard_split(&1, per_line))
      |> Enum.reduce([], &greedy_fill(&1, &2, per_line))
      |> Enum.reverse()
      |> Enum.take(max_lines)

    {size, ellipsize_last(lines, per_line)}
  end

  defp ellipsize_last([], _per_line), do: []

  defp ellipsize_last(lines, per_line) do
    {leading, [last]} = Enum.split(lines, -1)
    trimmed = last |> String.slice(0, max(per_line - 1, 0)) |> String.trim_trailing()
    leading ++ [trimmed <> "…"]
  end
end
