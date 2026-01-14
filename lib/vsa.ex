defmodule VSA do
  @moduledoc """
  Core functions that reflect volume spread analysis methodology.
  """
  alias VSA.Bar
  alias VSA.Context

  alias Decimal, as: D
  alias VSA.Thresholds

  @zero D.new(0)

  @doc """
  Initialize a new context for volume spread analysis.

  ## Parameters

  - `:max_bars` - Maximum number of bars to keep in memory for analysis (default 200).
  - `:bars_to_mean` - Number of bars to use for calculating the mean volume (default 20).
  - `:thresholds` - A `%VSA.Thresholds{}` struct or keyword list of threshold overrides.

  ## Threshold Options (when passing keyword list)

  - `:position_high_threshold` - Above this position (0-1) is considered "high" close (default 0.7)
  - `:position_low_threshold` - Below this position (0-1) is considered "low" close (default 0.3)
  - `:ultra_high_volume_factor` - Volume > this x mean is "ultra_high" (default 2.0)
  - `:high_volume_factor` - Volume > this x mean is "high" (default 1.5)
  - `:low_volume_factor` - Volume < this x mean is "low" (default 0.5)
  - `:very_low_volume_factor` - Volume < this x mean is "very_low" (default 0.25)
  - `:wide_spread_factor` - Spread > this x mean is "wide" (default 1.5)
  - `:narrow_spread_factor` - Spread < this x mean is "narrow" (default 0.7)
  - `:bars_to_extreme_reset` - Bars before resetting volume extreme tracking (default 200)

  ## Examples

      # Default configuration
      VSA.init()

      # Custom max_bars and bars_to_mean
      VSA.init(max_bars: 100, bars_to_mean: 30)

      # Custom thresholds inline
      VSA.init(
        max_bars: 100,
        position_high_threshold: Decimal.new("0.8"),
        ultra_high_volume_factor: Decimal.new("2.5")
      )

      # Pre-built thresholds struct
      {:ok, thresholds} = VSA.Thresholds.new(position_high_threshold: Decimal.new("0.6"))
      VSA.init(max_bars: 100, thresholds: thresholds)
  """
  def init(configuration \\ []) do
    max_bars = Keyword.get(configuration, :max_bars, 200)
    bars_to_mean = Keyword.get(configuration, :bars_to_mean, 20)
    thresholds = build_thresholds!(configuration)

    if thresholds.bars_to_extreme_reset > max_bars do
      raise ArgumentError, """
      :max_bars (#{max_bars}) can't be less than :bars_to_extreme_reset (#{thresholds.bars_to_extreme_reset})
      """
    end

    %Context{max_bars: max_bars, bars_to_mean: bars_to_mean, thresholds: thresholds}
  end

  defp build_thresholds!(configuration) do
    case Keyword.get(configuration, :thresholds) do
      %Thresholds{} = t ->
        t

      nil ->
        threshold_keys = [
          :position_high_threshold,
          :position_low_threshold,
          :ultra_high_volume_factor,
          :high_volume_factor,
          :low_volume_factor,
          :very_low_volume_factor,
          :wide_spread_factor,
          :narrow_spread_factor,
          :bars_to_extreme_reset
        ]

        threshold_opts = Keyword.take(configuration, threshold_keys)
        Thresholds.new!(threshold_opts)

      other when is_list(other) ->
        Thresholds.new!(other)
    end
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

  defp fill_bar(%Context{bars: [previous_bar | _], thresholds: thresholds} = ctx, raw_bar) do
    absolute_spread = absolute_spread(raw_bar)

    %Bar{
      spread: absolute_spread,
      high: raw_bar.high,
      low: raw_bar.low,
      time: DateTime.from_unix!(raw_bar.timestamp, :millisecond),
      close_price: raw_bar.close,
      closed: closed(absolute_spread, raw_bar, thresholds),
      opened: opened(absolute_spread, raw_bar, thresholds),
      volume: raw_bar.volume,
      direction: direction(previous_bar.close_price, raw_bar.close),
      relative_spread: relative_spread(ctx.mean_spread, absolute_spread, thresholds),
      relative_volume: relative_volume(ctx.mean_vol, raw_bar.volume, thresholds),
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

  defp closed(abs_spread, _, _thresholds) when abs_spread == @zero, do: :middle
  defp closed(_, %{close: c, low: l}, _thresholds) when c == l, do: :very_low
  defp closed(_, %{high: h, close: c}, _thresholds) when c == h, do: :very_high

  defp closed(abs_spread, %{close: c, low: l}, %Thresholds{} = thresholds) do
    position = D.div(D.sub(c, l), abs_spread)

    cond do
      D.lt?(position, thresholds.position_low_threshold) -> :low
      D.gt?(position, thresholds.position_high_threshold) -> :high
      true -> :middle
    end
  end

  defp opened(abs_spread, _, _thresholds) when abs_spread == @zero, do: :middle
  defp opened(_, raw_bar, _thresholds) when not is_map_key(raw_bar, :open), do: :middle
  defp opened(_, %{open: o, low: l}, _thresholds) when o == l, do: :very_low
  defp opened(_, %{high: h, open: o}, _thresholds) when o == h, do: :very_high

  defp opened(abs_spread, %{open: o, low: l}, %Thresholds{} = thresholds) do
    position = D.div(D.sub(o, l), abs_spread)

    cond do
      D.lt?(position, thresholds.position_low_threshold) -> :low
      D.gt?(position, thresholds.position_high_threshold) -> :high
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

  defp relative_spread(mean_spread, _, _thresholds) when mean_spread == @zero, do: :narrow
  defp relative_spread(_, spread, _thresholds) when spread == @zero, do: :narrow

  defp relative_spread(mean_spread, spread, %Thresholds{} = thresholds) do
    cond do
      D.gt?(spread, D.mult(thresholds.wide_spread_factor, mean_spread)) ->
        :wide

      D.lt?(spread, D.mult(thresholds.narrow_spread_factor, mean_spread)) ->
        :narrow

      true ->
        :average
    end
  end

  defp relative_volume(_, volume, _thresholds) when volume == @zero, do: :very_low
  defp relative_volume(mean_volume, _, _thresholds) when mean_volume == @zero, do: :average

  defp relative_volume(mean_volume, volume, %Thresholds{} = thresholds) do
    ratio = D.div(volume, mean_volume)

    cond do
      D.gt?(ratio, thresholds.ultra_high_volume_factor) ->
        :ultra_high

      D.gt?(ratio, thresholds.high_volume_factor) ->
        :high

      D.lt?(ratio, thresholds.very_low_volume_factor) ->
        :very_low

      D.lt?(ratio, thresholds.low_volume_factor) ->
        :low

      true ->
        :average
    end
  end
end
