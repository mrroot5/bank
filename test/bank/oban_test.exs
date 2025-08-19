defmodule Bank.ObanTest do
  use Bank.DataCase, async: true

  use Oban.Testing, repo: Bank.Repo

  describe "Oban config/1" do
    test "valid" do
      assert %Oban.Config{} = Oban.config()
    end
  end
end
