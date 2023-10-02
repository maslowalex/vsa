defmodule VSA.Context do
  @moduledoc """
  A data structure that represents the context of the VSA analysis.
  In VSA we are care about volume and spread primarily in relation to previous bars.

  So we would like to get the average volume and spread over the given period of time,
  and recalculate those values on each new bar.

  While experimenting with the input values, I find out that:

  *bars_to_mean* should be 12,
  *max_bars* should be 100

  This is close enough to reproduce the average volume shown by original VSA indicator
  """

  defstruct trend: :flat,
            max_bars: 100,
            bars_to_mean: 12,
            bars: [],
            mean_vol: 0.0,
            mean_spread: 0.0

  alias Decimal, as: D
  alias VSA.Context

  def set_mean_vol(%Context{} = ctx, []), do: ctx

  def set_mean_vol(%Context{bars: bars, bars_to_mean: bars_to_mean} = ctx) do
    latest_n_bars = Enum.take(bars, bars_to_mean)

    mean_vol =
      latest_n_bars
      |> Enum.reduce(D.new(0), &D.add(&1.volume, &2))
      |> D.div(Enum.count(latest_n_bars))

    %Context{ctx | mean_vol: mean_vol}
  end

  def set_mean_spread(%Context{bars: []} = ctx), do: ctx

  def set_mean_spread(%Context{bars: bars, bars_to_mean: bars_to_mean} = ctx) do
    latest_n_bars = Enum.take(bars, bars_to_mean)

    mean_spread =
      latest_n_bars
      |> Enum.reduce(D.new(0), &D.add(&1.spread, &2))
      |> D.div(Enum.count(latest_n_bars))

    %Context{ctx | mean_spread: mean_spread}
  end

  def latest_sma(%Context{bars: []}, _), do: nil

  def latest_sma(%Context{bars: bars}, incoming_close_price) do
    prices = [incoming_close_price | Enum.map(bars, & &1.close_price)]

    VSA.Sma.latest(prices)
  end
end
