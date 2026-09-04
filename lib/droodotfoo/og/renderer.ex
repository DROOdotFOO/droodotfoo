defmodule Droodotfoo.OG.Renderer do
  @moduledoc """
  Rasterizes card SVG to PNG, serialized through a single process.

  Two reasons this is a GenServer rather than a plain function.

  It owns the resvg font database, which is built once at boot; parsing the two
  Monaspace faces is the dominant per-render cost.

  And it serializes rendering. The resvg NIF declares no dirty scheduler, and
  production runs on a single shared vCPU, so a render blocks the whole BEAM
  for its duration. Funnelling every render through one process bounds that to
  one blocked scheduler no matter how many requests arrive at once.

  Nothing here raises: a missing font file, an unloadable NIF, or a call
  timeout all come back as `{:error, reason}` so the caller can fall back to
  the static image.
  """

  use GenServer

  require Logger

  alias Droodotfoo.OG.Svg

  @faces ~w(MonaspaceArgon-Medium.otf MonaspaceArgon-ExtraBold.otf)
  @family "Monaspace Argon"

  # Generous: a render measures in single-digit milliseconds, so hitting this
  # means something is badly wrong and the fallback is the right answer.
  @call_timeout 10_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Renders a card to PNG bytes.
  """
  @spec render(Droodotfoo.OG.Card.t()) :: {:ok, binary()} | {:error, term()}
  def render(card) do
    GenServer.call(__MODULE__, {:render, Svg.render(card)}, @call_timeout)
  catch
    # The exit reason embeds the full call arguments, and one of them is the
    # SVG document. Keep only the cause so a failing render does not write a
    # multi-kilobyte log line per request.
    :exit, {reason, {GenServer, :call, _args}} -> fail({:renderer_unavailable, reason})
    :exit, reason -> fail({:renderer_unavailable, reason})
  end

  @doc """
  Whether the font database loaded. Used by the boot warm-up to skip work that
  would only fail.
  """
  @spec available?() :: boolean()
  def available? do
    GenServer.call(__MODULE__, :available?, @call_timeout)
  catch
    :exit, _reason -> false
  end

  @spec font_dir() :: String.t()
  def font_dir, do: Application.app_dir(:droodotfoo, "priv/fonts")

  @spec font_files() :: [String.t()]
  def font_files, do: Enum.map(@faces, &Path.join(font_dir(), &1))

  # resvg requires this for all string inputs, even though the card SVG has no
  # external references.
  @spec resources_dir() :: String.t()
  def resources_dir, do: Application.app_dir(:droodotfoo, "priv")

  @impl true
  def init(_opts) do
    # Never fail to start: if the database is unavailable, calls return an
    # error and the controller serves the static fallback.
    {:ok, %{fontdb: build_fontdb()}}
  end

  @impl true
  def handle_call(:available?, _from, %{fontdb: fontdb} = state) do
    {:reply, match?({:ok, _}, fontdb), state}
  end

  def handle_call({:render, _svg}, _from, %{fontdb: {:error, reason}} = state) do
    {:reply, fail({:fontdb_unavailable, reason}), state}
  end

  def handle_call({:render, svg}, _from, %{fontdb: {:ok, db}} = state) do
    {:reply, rasterize(svg, db), state}
  end

  defp rasterize(svg, db) do
    started = System.monotonic_time()

    result =
      svg
      |> Resvg.svg_string_to_png_binary(fontdb: db, resources_dir: resources_dir())
      |> validate()

    :telemetry.execute(
      [:droodotfoo, :og, :render],
      %{duration: System.monotonic_time() - started},
      %{result: elem(result, 0)}
    )

    result
  rescue
    error -> fail(error)
  catch
    kind, error -> fail({kind, error})
  end

  # resvg reports failures as {:error, message}, but guard the success shape
  # too: serving a non-PNG body as image/png would break the card silently.
  defp validate({:ok, <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>> = png}),
    do: {:ok, png}

  defp validate({:ok, other}), do: fail({:not_a_png, byte_size(other)})
  defp validate({:error, reason}), do: fail(reason)

  defp build_fontdb do
    case Enum.reject(font_files(), &File.regular?/1) do
      [] ->
        Resvg.init_fontdb(
          font_files: font_files(),
          skip_system_fonts: true,
          resources_dir: resources_dir(),
          font_family: @family,
          monospace_family: @family,
          sans_serif_family: @family,
          serif_family: @family
        )

      missing ->
        Logger.warning("OG fonts missing, cards fall back to static: #{inspect(missing)}")
        {:error, {:missing_fonts, missing}}
    end
  rescue
    error -> {:error, error}
  catch
    kind, error -> {:error, {kind, error}}
  end

  defp fail(reason) do
    Logger.warning("OG render failed, serving static fallback: #{inspect(reason)}")
    {:error, reason}
  end
end
