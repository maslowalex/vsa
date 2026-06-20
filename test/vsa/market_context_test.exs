defmodule VSA.MarketContextTest do
  use ExUnit.Case, async: true

  alias VSA.{Bar, Level}
  alias Decimal, as: D

  defp raw(extra \\ %{}) do
    Map.merge(
      %{
        high: D.new("105"),
        low: D.new("95"),
        close: D.new("100"),
        open: D.new("96"),
        volume: D.new("1000"),
        timestamp: 1_700_000_000_000,
        finished: true
      },
      extra
    )
  end

  test "stamps optional caller-supplied :trend and :levels onto the bar" do
    levels = [%Level{price: D.new("110"), kind: :resistance}]

    %VSA.Context{bars: [bar | _]} = VSA.analyze([raw(%{trend: :up, levels: levels})])

    assert %Bar{trend: :up, levels: ^levels} = bar
  end

  test "defaults to nil trend and empty levels when the caller supplies neither" do
    %VSA.Context{bars: [bar | _]} = VSA.analyze([raw()])

    assert bar.trend == nil
    assert bar.levels == []
  end

  test "raises on an invalid trend value" do
    assert_raise ArgumentError, ~r/:trend must be one of/, fn ->
      VSA.analyze([raw(%{trend: :sideway})])
    end
  end

  test "raises when a level is not a %VSA.Level{}" do
    assert_raise ArgumentError, ~r/:levels/, fn ->
      VSA.analyze([raw(%{levels: [%{price: D.new("1"), kind: :resistance}]})])
    end
  end
end
