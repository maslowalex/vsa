defmodule VSA.Context do
  @moduledoc """
  A data structure that represents the context of the VSA analysis.
  In VSA we are care about volume and spread primarily in relation to previous bars.

  So we would like to get the average volume and spread over the given period of time,
  and recalculate those values on each new bar.
  """
  @zero Decimal.new(0)

  @derive JSON.Encoder
  defstruct max_bars: 200,
            bars_to_mean: 50,
            bars: [],
            mean_vol: @zero,
            mean_spread: @zero,
            volume_extreme: @zero,
            volume_extreme_set_bars_ago: 0,
            price_high: @zero,
            price_low: @zero,
            price_low_set_bars_ago: 0,
            price_high_set_bars_ago: 0,
            setup: nil

  alias Decimal, as: D
  alias VSA.Context

  @bars_to_extreme_reset Application.compile_env(:vsa, :bars_to_extreme_reset, 200)

  def maybe_capture_setup(%Context{} = context) do
    %{context | setup: VSA.Setup.capture(context)}
  end

  def set_mean_vol(%Context{} = ctx, []), do: ctx

  def set_mean_vol(%Context{bars: bars, bars_to_mean: bars_to_mean} = ctx) do
    latest_n_bars = Enum.take(bars, bars_to_mean)

    mean_vol =
      latest_n_bars
      |> Enum.reduce(@zero, &D.add(&1.volume, &2))
      |> D.div(Enum.count(latest_n_bars))

    %{ctx | mean_vol: mean_vol}
  end

  def set_mean_spread(%Context{bars: []} = ctx), do: ctx

  def set_mean_spread(%Context{bars: bars, bars_to_mean: bars_to_mean} = ctx) do
    latest_n_bars = Enum.take(bars, bars_to_mean)

    mean_spread =
      latest_n_bars
      |> Enum.reduce(@zero, &D.add(&1.spread, &2))
      |> D.div(Enum.count(latest_n_bars))

    %{ctx | mean_spread: mean_spread}
  end

  def maybe_set_volume_extreme(
        %Context{
          bars: [%VSA.Bar{relative_volume: :ultra_high, volume: v} | _],
          volume_extreme_set_bars_ago: volume_extreme_set_bars_ago
        } = ctx
      )
      when volume_extreme_set_bars_ago <= @bars_to_extreme_reset do
    if Decimal.gt?(v, ctx.volume_extreme) do
      %{ctx | volume_extreme: v, volume_extreme_set_bars_ago: 0}
    else
      %{ctx | volume_extreme_set_bars_ago: ctx.volume_extreme_set_bars_ago + 1}
    end
  end

  def maybe_set_volume_extreme(
        %Context{bars: [%VSA.Bar{relative_volume: :ultra_high, volume: v} | _]} = ctx
      ) do
    %{ctx | volume_extreme: v, volume_extreme_set_bars_ago: 0}
  end

  def maybe_set_volume_extreme(ctx),
    do: %{ctx | volume_extreme_set_bars_ago: ctx.volume_extreme_set_bars_ago + 1}

  def maybe_set_price_high_extreme(%Context{price_high: @zero, bars: bars} = ctx) do
    %{ctx | price_high: fetch_price_extreme(bars, :high)}
  end

  def maybe_set_price_high_extreme(
        %Context{
          bars: [%VSA.Bar{high: high} | _],
          price_high_set_bars_ago: price_high_set_bars_ago
        } = ctx
      ) do
    if Decimal.gt?(high, ctx.price_high) do
      %{ctx | price_high: high, price_high_set_bars_ago: 0}
    else
      %{ctx | price_high_set_bars_ago: price_high_set_bars_ago + 1}
    end
  end

  def maybe_set_price_high_extreme(ctx), do: ctx

  def maybe_set_price_low_extreme(%Context{price_low: @zero, bars: bars} = ctx) do
    %{ctx | price_low: fetch_price_extreme(bars, :low)}
  end

  def maybe_set_price_low_extreme(
        %Context{
          bars: [%VSA.Bar{low: low} | _],
          price_low_set_bars_ago: price_low_set_bars_ago
        } = ctx
      ) do
    if Decimal.lt?(low, ctx.price_low) do
      %{ctx | price_low: low, price_low_set_bars_ago: 0}
    else
      %{ctx | price_low_set_bars_ago: price_low_set_bars_ago + 1}
    end
  end

  def maybe_set_price_low_extreme(ctx), do: ctx

  def fetch_price_extreme(bars, :high) do
    bars
    |> Enum.max_by(& &1.high, Decimal)
    |> Map.fetch!(:high)
  end

  def fetch_price_extreme(bars, :low) do
    bars
    |> Enum.reject(&Decimal.eq?(&1.close_price, "0"))
    |> Enum.min_by(& &1.low, Decimal)
    |> Map.fetch!(:low)
  end
end
