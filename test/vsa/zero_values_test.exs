defmodule VSA.ZeroValuesTest do
  use ExUnit.Case, async: true

  # Exchange feeds encode zero as "0.00"/"0E-8" — coef 0 with a non-zero
  # exponent, which is structurally different from Decimal.new(0). The zero
  # guards in closed/opened/relative_spread/relative_volume must match
  # semantic zero, or a zero-volume/zero-spread bar reaches a 0/0 division.
  # Regression for a crash on thin listings with zero-volume daily bars.

  defp flat_bar(index, volume) do
    price = Decimal.new("1.00000000")

    %{
      high: price,
      low: price,
      close: price,
      volume: volume,
      timestamp: index * 86_400_000,
      finished: true
    }
  end

  test "zero-volume, zero-spread bars at odd exponents analyze without raising" do
    zero = Decimal.new("0E-8")
    bars = Enum.map(1..30, &flat_bar(&1, zero))

    assert %VSA.Context{bars: analyzed} = VSA.analyze(bars, VSA.init())
    assert Enum.count(analyzed) == 30
    assert %VSA.Bar{relative_volume: :very_low, relative_spread: :narrow} = hd(analyzed)
  end

  test "non-zero volume against a non-canonical zero mean classifies :average" do
    zero = Decimal.new("0E-8")
    bars = Enum.map(1..25, &flat_bar(&1, zero)) ++ [flat_bar(26, Decimal.new("100"))]

    assert %VSA.Context{bars: [%VSA.Bar{relative_volume: :average} | _]} =
             VSA.analyze(bars, VSA.init())
  end
end
