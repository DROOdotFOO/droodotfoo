defmodule Droodotfoo.DataCase do
  @moduledoc """
  Sets up an isolated Ecto sandbox for tests that touch the database.

  Use it like:

      use Droodotfoo.DataCase, async: true

  Each test gets its own sandbox owner; changes are rolled back at the end.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Droodotfoo.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
    end
  end

  setup tags do
    setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Droodotfoo.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end
