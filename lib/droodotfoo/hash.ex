defmodule Droodotfoo.Hash do
  @moduledoc """
  Canonical content-hash helpers.

  Centralizes the SHA-256 + lowercase-hex pattern used for change detection
  on wiki articles, library documents, and any other content the app
  fingerprints. Keeping the algorithm and encoding in one place means
  switching either is a single-file change.
  """

  @doc """
  Returns the lowercase hex SHA-256 digest of the input.

  ## Examples

      iex> Droodotfoo.Hash.sha256_hex("")
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

      iex> Droodotfoo.Hash.sha256_hex("hello")
      "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
  """
  @spec sha256_hex(iodata()) :: String.t()
  def sha256_hex(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
end
