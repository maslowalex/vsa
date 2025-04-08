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

  # TODO
  @zero Decimal.new(0)

  @derive JSON.Encoder
  defstruct trend: :flat,
            max_bars: 200,
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

  @bars_to_extreme_reset 200

  def maybe_capture_setup(%Context{} = context) do
    %Context{context | setup: VSA.Setup.capture(context)}
  end

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

  def maybe_set_volume_extreme(
        %Context{
          bars: [%VSA.Bar{relative_volume: :ultra_high, volume: v} | _],
          volume_extreme_set_bars_ago: volume_extreme_set_bars_ago
        } = ctx
      )
      when volume_extreme_set_bars_ago <= @bars_to_extreme_reset do
    if Decimal.gt?(v, ctx.volume_extreme) do
      %Context{ctx | volume_extreme: v, volume_extreme_set_bars_ago: 0}
    else
      %Context{ctx | volume_extreme_set_bars_ago: ctx.volume_extreme_set_bars_ago + 1}
    end
  end

  def maybe_set_volume_extreme(
        %Context{bars: [%VSA.Bar{relative_volume: :ultra_high, volume: v} | _]} = ctx
      ) do
    %Context{ctx | volume_extreme: v, volume_extreme_set_bars_ago: 0}
  end

  def maybe_set_volume_extreme(ctx),
    do: %Context{ctx | volume_extreme_set_bars_ago: ctx.volume_extreme_set_bars_ago + 1}

  def latest_sma(%Context{bars: []}, _), do: nil

  def latest_sma(%Context{bars: bars}, incoming_close_price) do
    VSA.SMA.latest(bars, incoming_close_price)
  end

  def latest_ema(%Context{bars: []}, _), do: nil

  def latest_ema(%Context{bars: bars}, incoming_close_price) do
    VSA.EMA.latest(bars, incoming_close_price)
  end

  def maybe_set_price_high_extreme(%Context{price_high: @zero, bars: bars} = ctx) do
    %Context{ctx | price_high: fetch_price_extreme(bars, :high)}
  end

  def maybe_set_price_high_extreme(
        %Context{
          bars: [%VSA.Bar{close_price: close_price} | _],
          price_high_set_bars_ago: price_high_set_bars_ago
        } = ctx
      ) do
    if Decimal.gt?(close_price, ctx.price_high) do
      %Context{ctx | price_high: close_price, price_high_set_bars_ago: 0}
    else
      %Context{ctx | price_high_set_bars_ago: price_high_set_bars_ago + 1}
    end
  end

  def maybe_set_price_high_extreme(ctx) do
    ctx
  end

  def maybe_set_price_low_extreme(%Context{price_low: @zero, bars: bars} = ctx) do
    %Context{ctx | price_low: fetch_price_extreme(bars, :low)}
  end

  def maybe_set_price_low_extreme(
        %Context{
          bars: [%VSA.Bar{close_price: close_price} | _],
          price_low_set_bars_ago: price_low_set_bars_ago
        } = ctx
      ) do
    if Decimal.lt?(close_price, ctx.price_low) do
      %Context{ctx | price_low: close_price, price_low_set_bars_ago: 0}
    else
      %Context{ctx | price_low_set_bars_ago: price_low_set_bars_ago + 1}
    end
  end

  def maybe_set_price_low_extreme(ctx), do: ctx

  def fetch_price_extreme(bars, :high) do
    bars
    |> Enum.max_by(& &1.close_price, Decimal)
    |> Map.fetch!(:close_price)
  end

  def fetch_price_extreme(bars, :low) do
    bars
    |> Enum.reject(&Decimal.eq?(&1.close_price, "0"))
    |> Enum.min_by(& &1.close_price, Decimal)
    |> Map.fetch!(:close_price)
  end
end
