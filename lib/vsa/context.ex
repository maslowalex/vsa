defmodule VSA.Context do
  @moduledoc """
  While experimenting with the input values, I find out that:

  *bars_to_mean* should be 12,
  *max_bars* should be 100

  This is close enough to reproduce the average volume shown by original VSA indicator
  """

  defstruct trend: :flat, max_bars: 100, bars_to_mean: 12, bars: [], mean_vol: 0.0, mean_spread: 0.0

  alias Decimal, as: D
  alias VSA.Context

  def set_mean_vol(%Context{} = ctx, []), do: ctx

  def set_mean_vol(%Context{} = ctx, bars) do
    mean_vol = bars |> Enum.reduce(D.new(0), &D.add(&1.vol, &2)) |> D.div(Enum.count(bars))

    %Context{ctx | mean_vol: mean_vol}
  end

  def set_mean_spread(%Context{} = ctx, []), do: ctx

  def set_mean_spread(%Context{} = ctx, bars) do
    mean_spread =
      Enum.reduce(bars, D.new(0), fn bar, acc ->
        spread = D.sub(bar.high, bar.low)

        D.add(spread, acc) |> D.div(Enum.count(bars))
      end)

    %Context{ctx | mean_spread: mean_spread}
  end
end
