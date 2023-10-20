defmodule VSA do
  @moduledoc """
  Core functions that reflect volume spread analysis methodology
  """

  alias VSA.Bar
  alias VSA.Context

  alias Decimal, as: D

  @doc """
  Analyze the collection of %VSA.Bar{} and annotates it with VSA-specific values
  """
  @spec analyze(list(VSA.Bar.t())) :: list(VSA.Bar.t())
  def analyze(raw_bars, context \\ %Context{}) when is_list(raw_bars) do
    Enum.reduce(raw_bars, context, fn raw_bar, context ->
      context
      |> adjust_bars(raw_bar)
      |> Context.set_mean_vol()
      |> Context.set_mean_spread()
      |> Context.maybe_set_volume_extreme()
    end)
  end

  defp adjust_bars(%Context{bars: [%Bar{tag: tag} = bar_to_confirm | tail_bars]} = ctx, raw_bar)
       when not is_nil(tag) do
    maybe_confirmed_bar = VSA.Indicator.confirm(bar_to_confirm, raw_bar.close)
    bars = [maybe_confirmed_bar | tail_bars]
    ctx = %Context{ctx | bars: bars}

    maybe_tagged_bar =
      ctx
      |> fill_bar(raw_bar)
      |> then(fn filled_bar -> VSA.Indicator.assign(ctx, filled_bar) end)

    %Context{ctx | bars: preserve_bars_length(ctx.max_bars, bars, maybe_tagged_bar)}
  end

  defp adjust_bars(%Context{bars: bars} = ctx, raw_bar) do
    maybe_tagged_bar =
      ctx
      |> fill_bar(raw_bar)
      |> then(fn filled_bar -> VSA.Indicator.assign(ctx, filled_bar) end)

    %Context{ctx | bars: preserve_bars_length(ctx.max_bars, bars, maybe_tagged_bar)}
  end

  defp preserve_bars_length(max_bars, bars, incoming_bar) do
    if length(bars) === max_bars do
      [incoming_bar | List.delete_at(bars, -1)]
    else
      [incoming_bar | bars]
    end
  end

  defp fill_bar(%Context{bars: [previous_bar | _]} = ctx, raw_bar) do
    absolute_spread = absolute_spread(raw_bar)

    %Bar{
      spread: absolute_spread,
      high: raw_bar.high,
      low: raw_bar.low,
      time: DateTime.from_unix!(raw_bar.ts, :millisecond),
      close_price: raw_bar.close,
      closed: closed(absolute_spread, raw_bar),
      opened: opened(absolute_spread, raw_bar),
      volume: raw_bar.vol,
      direction: direction(previous_bar.close_price, raw_bar.close),
      relative_spread: relative_spread(ctx.mean_spread, absolute_spread),
      relative_volume: relative_volume(ctx.mean_vol, raw_bar.vol),
      tag: nil,
      # Not sure it's belongs here
      sma: Context.latest_sma(ctx, raw_bar.close)
    }
  end

  defp fill_bar(_ctx, raw_bar) do
    %Bar{
      high: raw_bar.high,
      low: raw_bar.low,
      time: DateTime.from_unix!(raw_bar.ts, :millisecond),
      close_price: raw_bar.close,
      volume: raw_bar.vol,
      spread: absolute_spread(raw_bar)
    }
  end

  # CHECK LATER
  # This values is from github gist by some dude, probably those values are make no sense
  #
  # very_high_close_bar = bar_range < 1.35
  # high_close_bar = bar_range < 2
  # mid_close_bar = (bar_range < 2.2) & (bar_range > 1.8)
  # down_close_bar = bar_range > 2
  @high_close D.new("2")
  @mid_low D.new("2.2")
  @mid_high D.new("1.8")
  @very_high_close D.new("1.35")

  defp closed(_, %{close: c, low: c}) do
    :very_low
  end

  defp closed(_, %{high: h, close: h}) do
    :very_high
  end

  defp closed(abs_spread, %{close: c, low: l}) do
    abs_spread
    |> D.div(D.sub(c, l))
    |> compare_with_ratio()
  end

  defp opened(_, %{open: o, low: o}) do
    :very_low
  end

  defp opened(_, %{high: h, close: h}) do
    :very_high
  end

  defp opened(abs_spread, %{open: o, low: l}) do
    abs_spread
    |> D.div(D.sub(o, l))
    |> compare_with_ratio()
  end

  defp compare_with_ratio(ratio) do
    cond do
      D.lt?(ratio, @mid_low) and D.gt?(ratio, @mid_high) ->
        :middle

      D.gt?(ratio, @high_close) ->
        :low

      D.lt?(ratio, @mid_high) ->
        :high

      true ->
        :very_high
    end
  end

  defp direction(eq, eq), do: :level

  defp direction(prev, current) do
    if D.gt?(current, prev) do
      :up
    else
      :down
    end
  end

  defp absolute_spread(%{low: l, high: h}) do
    D.sub(h, l)
  end

  @wide_spread_factor D.new("1.5")
  @narrow_spread_factor D.new("0.7")

  defp relative_spread(mean_spread, spread) do
    cond do
      D.gt?(spread, D.mult(@wide_spread_factor, mean_spread)) ->
        :wide

      D.lt?(spread, D.mult(@narrow_spread_factor, mean_spread)) ->
        :narrow

      true ->
        :average
    end
  end

  @very_low_volume_factor D.new("3")
  @low_volume_factor D.new("1.25")
  @average_volume_factor D.new("0.88")
  @high_volume_factor D.new("0.6")
  @zero D.new("0")

  defp relative_volume(_mean_volume, @zero), do: :very_low

  defp relative_volume(mean_volume, volume) do
    factor = D.div(mean_volume, volume)

    cond do
      D.gt?(factor, @low_volume_factor) ->
        :very_low

      D.lt?(factor, @high_volume_factor) ->
        :ultra_high

      D.lt?(factor, @very_low_volume_factor) and D.gt?(factor, @average_volume_factor) ->
        :average

      D.gt?(factor, @average_volume_factor) and D.lt?(factor, @very_low_volume_factor) ->
        :low

      true ->
        :high
    end
  end
end

# %{
#   close: 30091.7,
#   high: 30120.0,
#   low: 30052.8,
#   open: 30115.4,
#   confirm: 3891883.95989609,
#   ts: 1687972500000.0,
#   vol: 129.34263388,
#   volCcy: 3891883.95989609
# }
