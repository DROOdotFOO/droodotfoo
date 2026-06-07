defmodule Droodotfoo.HashTest do
  use ExUnit.Case, async: true

  alias Droodotfoo.Hash

  describe "sha256_hex/1" do
    test "empty string maps to the documented SHA-256 of the empty input" do
      assert Hash.sha256_hex("") ==
               "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end

    test "the string 'hello' matches the documented SHA-256 digest" do
      assert Hash.sha256_hex("hello") ==
               "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    end

    test "output is 64 lowercase hex characters" do
      hash = Hash.sha256_hex("anything")

      assert String.length(hash) == 64
      assert hash =~ ~r/\A[0-9a-f]{64}\z/
    end

    test "different inputs produce different hashes" do
      refute Hash.sha256_hex("a") == Hash.sha256_hex("b")
    end

    test "accepts iodata input (list of binaries)" do
      assert Hash.sha256_hex(["foo", "bar"]) == Hash.sha256_hex("foobar")
    end
  end
end
