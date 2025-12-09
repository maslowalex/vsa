defmodule VSA do
  @moduledoc """
  Core functions that reflect volume spread analysis methodology.
  """
  alias VSA.Bar
  alias VSA.Context

  alias Decimal, as: D

  # Constants for close/open position calculations
  # Renamed for clarity
  # Above 70% of range
  @position_high_threshold Application.compile_env(:vsa, :position_high_threshold, D.new("0.7"))
  # Below 30% of range
  @position_low_threshold Application.compile_env(:vsa, :position_low_threshold, D.new("0.3"))
  # Fixed volume factors - now using volume/mean_volume ratio
  # Volume > 2x average
  @ultra_high_volume_factor Application.compile_env(:vsa, :ultra_high_volume_factor, D.new("2.0"))
  # Volume > 1.5x average
  @high_volume_factor Application.compile_env(:vsa, :high_volume_factor, D.new("1.5"))
  # Volume < 0.5x average
  @low_volume_factor Application.compile_env(:vsa, :low_volume_factor, D.new("0.5"))
  # Volume < 0.25x average
  @very_low_volume_factor Application.compile_env(:vsa, :very_low_volume_factor, D.new("0.25"))

  @zero D.new(0)

  @doc """
  Initialize a new context for volume spread analysis.

  ### Parameters
  :max_bars - Maximum number of bars to keep in memory for analysis (default is 200).
  :bars_to_mean - Number of bars to use for calculating the mean volume (default is 20).
  """
  def init(configuration \\ []) do
    bars_to_extreme_reset = Application.get_env(:vsa, :bars_to_extreme_reset, 20)
    max_bars = Keyword.get(configuration, :max_bars, 200)
    bars_to_mean = Keyword.get(configuration, :bars_to_mean, 20)

    if bars_to_extreme_reset > max_bars do
      raise """
      :max_bars can't be less then :bars_to_extreme_reset (currently #{max_bars})
      """
    end

    %Context{max_bars: max_bars, bars_to_mean: bars_to_mean}
  end

  @doc """
  Analyze the collection of %VSA.RawBar{} and annotates it with VSA-specific values
  """
  @spec analyze(list(VSA.Bar.t())) :: list(VSA.Bar.t())
  def analyze(raw_bars, context \\ %Context{})

  def analyze(raw_bars, context) when is_list(raw_bars) do
    Enum.reduce(raw_bars, context, &do_analyze/2)
  end

  def analyze(raw_bar, context) when is_map(raw_bar) do
    do_analyze(raw_bar, context)
  end

  defp do_analyze(raw_bar, context) do
    context
    |> add_raw_bar(raw_bar)
    |> maybe_set_two_bar_tag()
    |> Context.set_mean_vol()
    |> Context.set_mean_spread()
    |> Context.maybe_set_volume_extreme()
    |> Context.maybe_set_price_high_extreme()
    |> Context.maybe_set_price_low_extreme()
    |> Context.maybe_capture_setup()
  end

  def add_raw_bar(
        %Context{bars: [%Bar{tag: tag, finished: true} = bar_to_confirm | tail_bars]} = ctx,
        raw_bar
      )
      when not is_nil(tag) do
    # First fill and tag the new bar
    maybe_tagged_bar =
      ctx
      |> fill_bar(raw_bar)
      |> then(fn filled_bar -> Vsa.Tag.assign(ctx, filled_bar) end)

    # Then confirm the previous bar with the new bar's close price
    maybe_confirmed_bar = Vsa.Tag.confirm(bar_to_confirm, maybe_tagged_bar)
    bars = [maybe_confirmed_bar | tail_bars]
    ctx = %Context{ctx | bars: bars}

    %Context{ctx | bars: preserve_bars_length(ctx.max_bars, ctx.bars, maybe_tagged_bar)}
  end

  def add_raw_bar(%Context{bars: bars} = ctx, raw_bar) do
    maybe_tagged_bar =
      ctx
      |> fill_bar(raw_bar)
      |> then(fn filled_bar -> Vsa.Tag.assign(ctx, filled_bar) end)

    %Context{ctx | bars: preserve_bars_length(ctx.max_bars, bars, maybe_tagged_bar)}
  end

  defp maybe_set_two_bar_tag(ctx) do
    Vsa.Tag.set_two_bar_tag(ctx)
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
      time: DateTime.from_unix!(raw_bar.timestamp, :millisecond),
      close_price: raw_bar.close,
      closed: closed(absolute_spread, raw_bar),
      opened: opened(absolute_spread, raw_bar),
      volume: raw_bar.volume,
      direction: direction(previous_bar.close_price, raw_bar.close),
      relative_spread: relative_spread(ctx.mean_spread, absolute_spread),
      relative_volume: relative_volume(ctx.mean_vol, raw_bar.volume),
      tag: nil,
      finished: raw_bar.finished
    }
  end

  defp fill_bar(_ctx, raw_bar) do
    %Bar{
      high: raw_bar.high,
      low: raw_bar.low,
      time: DateTime.from_unix!(raw_bar.timestamp, :millisecond),
      close_price: raw_bar.close,
      volume: raw_bar.volume,
      spread: absolute_spread(raw_bar)
    }
  end

  defp closed(abs_spread, _) when abs_spread == @zero, do: :middle
  defp closed(_, %{close: c, low: l}) when c == l, do: :very_low
  defp closed(_, %{high: h, close: c}) when c == h, do: :very_high

  defp closed(abs_spread, %{close: c, low: l}) do
    # Calculate normalized position (0 to 1) where close is within the range
    position = D.div(D.sub(c, l), abs_spread)

    cond do
      D.lt?(position, @position_low_threshold) -> :low
      D.gt?(position, @position_high_threshold) -> :high
      true -> :middle
    end
  end

  defp opened(abs_spread, _) when abs_spread == @zero, do: :middle

  # Check if bar has open field
  defp opened(_, raw_bar) when not is_map_key(raw_bar, :open), do: :middle

  defp opened(_, %{open: o, low: l}) when o == l, do: :very_low
  # Fixed: checking open == high
  defp opened(_, %{high: h, open: o}) when o == h, do: :very_high

  defp opened(abs_spread, %{open: o, low: l}) do
    # Calculate normalized position (0 to 1) where open is within the range
    position = D.div(D.sub(o, l), abs_spread)

    cond do
      D.lt?(position, @position_low_threshold) -> :low
      D.gt?(position, @position_high_threshold) -> :high
      true -> :middle
    end
  end

  defp direction(prev, current) do
    cond do
      D.eq?(prev, current) -> :level
      D.gt?(current, prev) -> :up
      true -> :down
    end
  end

  defp absolute_spread(%{low: l, high: h}) do
    D.sub(h, l)
  end

  @wide_spread_factor D.new("1.5")
  @narrow_spread_factor D.new("0.7")

  defp relative_spread(mean_spread, _) when mean_spread == @zero, do: :narrow
  defp relative_spread(_, spread) when spread == @zero, do: :narrow

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

  defp relative_volume(_, volume) when volume == @zero, do: :very_low
  defp relative_volume(mean_volume, _) when mean_volume == @zero, do: :average

  defp relative_volume(mean_volume, volume) do
    # Fixed: Now correctly calculating volume ratio (volume/mean_volume)
    ratio = D.div(volume, mean_volume)

    cond do
      D.gt?(ratio, @ultra_high_volume_factor) ->
        :ultra_high

      D.gt?(ratio, @high_volume_factor) ->
        :high

      D.lt?(ratio, @very_low_volume_factor) ->
        :very_low

      D.lt?(ratio, @low_volume_factor) ->
        :low

      true ->
        :average
    end
  end
end
