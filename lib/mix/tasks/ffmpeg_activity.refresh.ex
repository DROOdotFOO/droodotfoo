defmodule Mix.Tasks.FfmpegActivity.Refresh do
  @moduledoc """
  Regenerate `priv/ffmpeg_activity.json` from a local FFmpeg clone.

  Reads commit dates from `git log --all --author <author>` and writes a
  list of `%{"date" => "YYYY-MM-DD", "count" => n}` entries covering the
  past 365 days. `Droodotfoo.Forgejo.Activity` reads this at runtime and
  the top-level aggregator merges it with GitHub activity.

  Run manually whenever you push commits to FFmpeg:

      mix ffmpeg_activity.refresh
      mix ffmpeg_activity.refresh --repo /path/to/ffmpeg --author DROOdotFOO

  Defaults: repo at `../ffmpeg` relative to this app, author `DROOdotFOO`.
  """

  use Mix.Task

  @shortdoc "Refresh priv/ffmpeg_activity.json from a local FFmpeg clone"

  @default_repo "../ffmpeg"
  @default_author "DROOdotFOO"

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} =
      OptionParser.parse(argv,
        strict: [repo: :string, author: :string, output: :string]
      )

    repo = Keyword.get(opts, :repo, @default_repo) |> Path.expand()
    author = Keyword.get(opts, :author, @default_author)
    output = Keyword.get(opts, :output, default_output())

    unless File.dir?(Path.join(repo, ".git")) do
      Mix.raise("Not a git repo: #{repo}")
    end

    Mix.shell().info("Reading #{author}'s commits from #{repo}")
    counts = commit_counts_by_date(repo, author)

    if map_size(counts) == 0 do
      Mix.shell().info("No commits found for author #{inspect(author)}")
    end

    entries =
      counts
      |> Enum.sort_by(fn {date, _} -> date end)
      |> Enum.map(fn {date, count} -> %{"date" => date, "count" => count} end)

    File.mkdir_p!(Path.dirname(output))
    File.write!(output, Jason.encode!(entries, pretty: true) <> "\n")

    Mix.shell().info("Wrote #{length(entries)} active days to #{output}")
  end

  defp commit_counts_by_date(repo, author) do
    {output, 0} =
      System.cmd(
        "git",
        [
          "-C",
          repo,
          "log",
          "--all",
          "--author=#{author}",
          "--since=1 year ago",
          "--format=%ad",
          "--date=short"
        ],
        stderr_to_stdout: true
      )

    output
    |> String.split("\n", trim: true)
    |> Enum.frequencies()
  end

  defp default_output do
    Application.app_dir(:droodotfoo, "priv/ffmpeg_activity.json")
    |> case do
      "/" <> _ = compiled_path ->
        # When running from source, app_dir resolves to _build; we want the source priv/.
        source_priv =
          compiled_path
          |> String.replace(~r{/_build/[^/]+/lib/droodotfoo/priv}, "/priv")

        if File.dir?(Path.dirname(source_priv)), do: source_priv, else: compiled_path

      other ->
        other
    end
  end
end
