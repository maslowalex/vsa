defmodule VSA.TagProvenanceTest do
  use ExUnit.Case, async: true

  alias VSA.{Bar, TagEvent}
  alias Decimal, as: D

  defp base_bar(fields) do
    defaults = %{
      time: ~U[2023-01-01 10:00:00Z],
      close_price: D.new("100"),
      spread: D.new("5"),
      volume: D.new("1000")
    }

    struct!(Bar, Map.merge(defaults, fields))
  end

  describe "Bar.put_tag/4" do
    test "sets tag/status and prepends a TagEvent (newest-first), preserving history" do
      bar =
        base_bar(%{})
        |> Bar.put_tag(:test, :assigned, ~U[2023-01-01 10:00:00Z])
        |> Bar.put_tag(:test, :unconfirmed, ~U[2023-01-01 10:05:00Z])

      assert bar.tag == :test
      assert bar.status == :unconfirmed

      assert [
               %TagEvent{tag: :test, status: :unconfirmed, at: ~U[2023-01-01 10:05:00Z]},
               %TagEvent{tag: :test, status: :assigned, at: ~U[2023-01-01 10:00:00Z]}
             ] = bar.tag_history
    end
  end

  describe "Vsa.Tag.confirm/2 provenance" do
    test "failed confirmation keeps the tag, marks it unconfirmed, and records the full transition" do
      tagged =
        base_bar(%{close_price: D.new("95"), direction: :down})
        |> Bar.put_tag(:test, :assigned, ~U[2023-01-01 10:00:00Z])

      # :test is a strength tag — a failed confirmation is when the next bar does NOT close higher
      next = base_bar(%{close_price: D.new("90"), time: ~U[2023-01-01 10:05:00Z]})

      result = Vsa.Tag.confirm(tagged, next)

      assert result.tag == :test
      assert result.status == :unconfirmed
      assert Enum.map(result.tag_history, & &1.status) == [:unconfirmed, :assigned]
      assert Enum.all?(result.tag_history, &(&1.tag == :test))
    end

    test "successful confirmation keeps the tag and records it as confirmed" do
      tagged =
        base_bar(%{close_price: D.new("95")})
        |> Bar.put_tag(:test, :assigned, ~U[2023-01-01 10:00:00Z])

      next = base_bar(%{close_price: D.new("100"), time: ~U[2023-01-01 10:05:00Z]})

      result = Vsa.Tag.confirm(tagged, next)

      assert result.tag == :test
      assert result.status == :confirmed
      assert [%TagEvent{status: :confirmed}, %TagEvent{status: :assigned}] = result.tag_history
    end
  end
end
