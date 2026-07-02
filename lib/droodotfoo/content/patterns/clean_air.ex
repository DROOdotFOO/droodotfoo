defmodule Droodotfoo.Content.Patterns.CleanAir do
  @moduledoc """
  Clean-air pattern generator for the "Clean Air" post.

  One coherent diagram: an upwind beat. Every track leaves the same start
  line at the bottom and races the same windward mark at the top, so the
  whole image reads as a single course rather than scattered marks.

  Up the middle, the fleet bunches into a knot of converging tracks,
  covering each other, each one fading at both ends so it reads as moving
  air rather than a drawn line (a gust of brightness drifts along the tracks
  when animated). Out to the left, one bold, steady line splits away into
  clean air and tacks decisively to the mark. Laylines frame the approach.
  """

  alias Droodotfoo.Content.{PatternConfig, RandomGenerator, SVGBuilder}
  alias Droodotfoo.Content.Patterns.Base

  @white "#ffffff"

  @spec generate(number, number, RandomGenerator.t(), map, boolean) ::
          {[SVGBuilder.element()], RandomGenerator.t()}
  def generate(width, height, rng, _palette, animate \\ false) do
    config = PatternConfig.clean_air_config()

    {fleet_count, rng} = RandomGenerator.uniform_range(rng, config.fleet_count)
    fleet_count = trunc(fleet_count)

    mark = {width * 0.5, height * 0.14}
    start_y = height * 0.88

    {fleet, rng} = fleet(width, mark, start_y, fleet_count, animate, rng)

    # The committed line: leaves the start well left of the pack, tacks out
    # into clean air, and drives to the mark.
    line_pts = [
      {width * 0.34, start_y},
      {width * 0.25, height * 0.58},
      {width * 0.40, height * 0.33},
      elem_pt(mark)
    ]

    elements =
      List.flatten([
        start_line(width, start_y),
        laylines(width, height, mark, start_y, animate),
        fleet,
        committed_line(line_pts, mark, animate),
        windward_mark(mark, animate)
      ])

    {elements, rng}
  end

  # -- Start line ----------------------------------------------------------
  # The shared origin. Every track begins on it.

  defp start_line(width, start_y) do
    x1 = width * 0.30
    x2 = width * 0.70

    line =
      SVGBuilder.line(r(x1), r(start_y), r(x2), r(start_y), %{})
      |> SVGBuilder.with_attrs(%{
        stroke: @white,
        "stroke-width": 1.0,
        opacity: 0.22,
        "stroke-dasharray": "10 8"
      })

    pins =
      for px <- [x1, x2] do
        SVGBuilder.circle(r(px), r(start_y), 4, %{})
        |> SVGBuilder.with_attrs(%{
          fill: "none",
          stroke: @white,
          "stroke-width": 1.4,
          opacity: 0.35
        })
      end

    [line | pins]
  end

  # -- Laylines ------------------------------------------------------------
  # The geometric envelope of the beat, fanning down from the mark.

  defp laylines(width, height, {mx, my}, _start_y, animate) do
    [
      {width * 0.27, height * 0.82},
      {width * 0.73, height * 0.82}
    ]
    |> Enum.map(fn {ex, ey} ->
      el =
        SVGBuilder.line(r(mx), r(my), r(ex), r(ey), %{})
        |> SVGBuilder.with_attrs(%{
          stroke: @white,
          "stroke-width": 1.0,
          opacity: 0.13,
          "stroke-dasharray": "9 11"
        })

      if animate, do: SVGBuilder.with_class(el, "ca-wind"), else: el
    end)
  end

  # -- The fleet -----------------------------------------------------------
  # Tracks that leave the start bunched in the center and tack up the beat,
  # converging on the mark and crossing each other on the way: covering.

  defp fleet(width, {mx, my}, start_y, n, animate, rng) do
    Enum.flat_map_reduce(0..(n - 1), rng, fn k, r0 ->
      {sx_f, r1} = RandomGenerator.uniform_float(r0, 0.42, 0.64)
      {amp_f, r2} = RandomGenerator.uniform_float(r1, 0.045, 0.095)
      {phase, r3} = RandomGenerator.uniform_float(r2, 0.0, 6.28)
      {op, r4} = RandomGenerator.uniform_float(r3, 0.26, 0.48)

      sx = sx_f * width
      amp = amp_f * width
      tacks = 3
      steps = 24

      points =
        for s <- 0..steps do
          t = s / steps
          y = start_y + (my - start_y) * t
          base_x = sx + (mx - sx) * t
          # Tack amplitude shrinks toward the mark, so tracks converge there.
          off = :math.sin(phase + t * :math.pi() * tacks) * amp * (1.0 - t)
          {base_x + off, y, t}
        end

      segments =
        points
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [{x0, y0, t0}, {x1, y1, t1}] ->
          tm = (t0 + t1) / 2.0
          # Fade each end to nothing so the streamline dissolves into the
          # field instead of ending on a hard cap. No visible line-ends.
          seg_op = op * :math.sin(:math.pi() * tm)
          fleet_segment(x0, y0, x1, y1, seg_op, tm, k, animate)
        end)

      {segments, r4}
    end)
  end

  # One faded segment of a fleet streamline. Tracks are split into many so
  # the ends can taper and a gust of brightness can drift along each one when
  # animated, reading as moving air rather than a blinking squiggle.
  defp fleet_segment(x0, y0, x1, y1, seg_op, tm, k, animate) do
    seg_op = r(seg_op)

    el =
      SVGBuilder.path("M #{r(x0)},#{r(y0)} L #{r(x1)},#{r(y1)}", %{})
      |> SVGBuilder.with_attrs(%{
        fill: "none",
        stroke: @white,
        "stroke-width": 1.4,
        opacity: seg_op,
        "stroke-linecap": "round"
      })

    if animate do
      SVGBuilder.with_class(el, "ca-gust")
      |> SVGBuilder.with_attrs(%{style: "--op: #{seg_op}; --seg: #{r(tm)}; --i: #{k}"})
    else
      el
    end
  end

  # -- The committed line --------------------------------------------------
  # One bold, steady track: a soft underlay for presence, sharp waypoint
  # tacks, an arrowhead into the mark. Solid and near-still: it commits.

  defp committed_line(pts, mark, animate) do
    d = path_d(pts)

    underlay =
      SVGBuilder.path(d, %{})
      |> SVGBuilder.with_attrs(%{
        fill: "none",
        stroke: @white,
        "stroke-width": 8.0,
        opacity: 0.1,
        "stroke-linecap": "round",
        "stroke-linejoin": "round"
      })

    line =
      SVGBuilder.path(d, %{})
      |> SVGBuilder.with_attrs(%{
        fill: "none",
        stroke: @white,
        "stroke-width": 3.4,
        opacity: 0.95,
        "stroke-linecap": "round",
        "stroke-linejoin": "round"
      })

    waypoints =
      pts
      |> Enum.drop(1)
      |> Enum.drop(-1)
      |> Enum.map(fn {x, y} ->
        SVGBuilder.circle(r(x), r(y), 4.5, %{})
        |> SVGBuilder.with_attrs(%{
          fill: "#000000",
          stroke: @white,
          "stroke-width": 2.0,
          opacity: 0.95
        })
      end)

    arrow = arrowhead(List.last(pts), mark)

    line = if animate, do: SVGBuilder.with_class(line, "ca-line"), else: line
    arrow = if animate, do: SVGBuilder.with_class(arrow, "ca-line"), else: arrow

    [underlay, line | waypoints] ++ [arrow]
  end

  defp arrowhead({fx, fy}, {mx, my}) do
    dx = mx - fx
    dy = my - fy
    len = :math.sqrt(dx * dx + dy * dy)
    {nx, ny} = if len < 0.01, do: {0.0, -1.0}, else: {dx / len, dy / len}
    {px, py} = {-ny, nx}

    tip = {fx + nx * 16, fy + ny * 16}
    base1 = {fx - px * 7, fy - py * 7}
    base2 = {fx + px * 7, fy + py * 7}

    SVGBuilder.polygon(vtp([tip, base1, base2]), %{})
    |> SVGBuilder.with_attrs(%{
      fill: @white,
      "fill-opacity": 0.95,
      stroke: @white,
      "stroke-width": 1.0,
      "stroke-linejoin": "round"
    })
  end

  # -- Windward mark -------------------------------------------------------
  # The shared destination. Focal node at the top of the beat.

  defp windward_mark({mx, my}, animate) do
    s = 11

    diamond =
      SVGBuilder.polygon(vtp([{mx, my - s}, {mx + s, my}, {mx, my + s}, {mx - s, my}]), %{})
      |> SVGBuilder.with_attrs(%{
        fill: @white,
        "fill-opacity": 0.18,
        stroke: @white,
        "stroke-width": 2.0,
        "stroke-opacity": 0.9,
        "stroke-linejoin": "round"
      })

    ring =
      SVGBuilder.circle(r(mx), r(my), r(s * 1.9), %{})
      |> SVGBuilder.with_attrs(%{
        fill: "none",
        stroke: @white,
        "stroke-width": 0.8,
        opacity: 0.3,
        "stroke-dasharray": "3 5"
      })

    parts = [ring, diamond]
    if animate, do: Enum.map(parts, &SVGBuilder.with_class(&1, "ca-mark")), else: parts
  end

  # -- Helpers -------------------------------------------------------------

  defp elem_pt({x, y}), do: {x, y}

  defp path_d(points) do
    points
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {{x, y}, i} ->
      if i == 0, do: "M #{r(x)},#{r(y)}", else: "L #{r(x)},#{r(y)}"
    end)
  end

  defp vtp(vertices), do: Enum.map_join(vertices, " ", fn {x, y} -> "#{r(x)},#{r(y)}" end)

  defp r(val), do: Float.round(val * 1.0, 2)

  @spec generate_svg(String.t(), number, number, boolean, [String.t()]) :: String.t()
  def generate_svg(slug, width, height, animate \\ false, tags \\ []) do
    Base.generate_svg(__MODULE__, :clean_air, slug, width, height, animate, tags)
  end
end
