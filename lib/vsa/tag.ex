defmodule Vsa.Tag do
  @moduledoc """
  Assigns VSA principles ("tags") to bars and (dis)confirms them.

  ## Detection

  `assign/2` runs an ordered list of detectors against the current `VSA.Context` and
  `VSA.Bar`, keeping the **first** match. Detectors are ordered most-specific first; the
  generic `:professional_buying` / `:professional_selling` are the fallback, so a richer
  principle (a selling climax, stopping volume, …) is preferred over the generic climactic
  read of the same bar. Each detector returns `{:ok, tag}` or `:skip`.

  Two- and N-bar principles read the prior bars from `context.bars` (newest first); the bar
  being classified is the second argument, since it has not yet been prepended to the
  context.

  ## Confirmation

  A tag is provisional. When the next bar arrives, `confirm/2` records whether it confirmed
  the read — a strength tag needs the next bar to close higher, a weakness tag lower. The
  outcome is written as `:status` (`:confirmed` / `:unconfirmed`) onto the bar's
  `:tag_history`; the original tag is preserved (a failed test stays `:test`, now
  `:unconfirmed`).

  ## Principles

  ### Signs of strength (appear on down bars / after a fall)

    * `:selling_climax` — wide, ultra-high-volume down bar closing off the low after a down
      move; marks the low.
    * `:stopping_volume` — high/ultra-high-volume down bar whose spread narrows as it falls
      and which closes off the low; demand absorbing supply.
    * `:bag_holding` — two-bar: a heavy-supply bar, then a bar that pushes to a new low (bad
      news) yet closes mid/high; demand has overcome supply.
    * `:absorption_volume` — wide up bar closing on its high through an old resistance (the
      documented exception to "wide high-volume up bar = weakness"). Needs injected `:levels`.
    * `:shakeout` — wide down bar opening and closing high on high volume; shakes out weak
      holders in an up move.
    * `:test` / `:no_supply` — a low-volume down bar showing no selling pressure; emitted as
      `:no_supply` when there is already strength in the background.
    * `:professional_buying` — generic ultra-high-volume down bar at a volume/price extreme.
    * `:bottom_reversal` — two-bar reversal up off a new low.

  ### Signs of weakness (appear on up bars / after a rally)

    * `:buying_climax` — wide, ultra-high-volume up bar closing off the high into fresh
      ground; marks the top.
    * `:end_of_rising_market` — narrow, high/ultra-high-volume up bar closing off the high
      into fresh ground.
    * `:no_result_from_effort` — an effort to rise answered by a wide down bar closing on the
      low; the effort produced nothing.
    * `:churning` — ultra-high volume on a narrow spread after another high-volume bar;
      activity without progress.
    * `:upthrust` — a bar marked up then sold back to close on the low, trapping buyers.
    * `:no_demand` / `:no_demand_at_top` — a low-volume up bar lacking professional demand;
      `:no_demand_at_top` when it stalls at an old resistance (needs injected `:levels`).
    * `:wide_spread_down_through_support` — a wide down bar closing on its low through an old
      support. Needs injected `:levels`.
    * `:professional_selling` — generic ultra-high-volume up bar at a volume/price extreme.
    * `:top_reversal` — two-bar reversal down off a new high.
  """

  alias Decimal, as: D

  alias VSA.Bar
  alias VSA.Context

  # Tags whose confirmation needs the next bar to close higher (strength) / lower (weakness).
  # New principles must be added here so `confirm/2` can (dis)confirm them.
  @strength_tags [
    :shakeout,
    :test,
    :professional_buying,
    :bottom_reversal,
    :selling_climax,
    :stopping_volume,
    :bag_holding,
    :absorption_volume,
    :no_supply
  ]
  @weakness_tags [
    :no_demand,
    :upthrust,
    :professional_selling,
    :top_reversal,
    :buying_climax,
    :end_of_rising_market,
    :no_result_from_effort,
    :no_demand_at_top,
    :wide_spread_down_through_support
  ]

  @zero D.new(0)

  @doc """
  For now the only two indicators here is top reversal and bottom reversal
  """
  def set_two_bar_tag(
        %Context{
          bars: [
            %Bar{
              direction: :down,
              closed: current_closed,
              relative_spread: spread,
              low: current_low
            } = current,
            %Bar{
              direction: :up,
              closed: init_closed,
              relative_spread: spread,
              low: previous_low,
              relative_volume: relative_volume
            } =
              previous_bar
            | rest_of_the_bars
          ]
          # price_high_set_bars_ago: 0
        } = ctx
      )
      when spread in [:average, :wide] and init_closed in [:very_high, :high] and
             current_closed in [:very_low, :low] and relative_volume in [:high, :ultra_high] do
    if D.lt?(current_low, previous_low) do
      %Context{
        ctx
        | bars: [
            Bar.put_tag(current, :top_reversal, :assigned, current.time),
            previous_bar | rest_of_the_bars
          ]
      }
    else
      ctx
    end
  end

  def set_two_bar_tag(
        %Context{
          bars: [
            %Bar{
              direction: :up,
              closed: current_closed,
              relative_spread: spread,
              high: current_high
            } = current,
            %Bar{
              direction: :down,
              closed: init_closed,
              relative_spread: spread,
              high: previous_high,
              relative_volume: relative_volume
            } =
              previous_bar
            | rest_of_the_bars
          ]
          # price_low_set_bars_ago: 0
        } = ctx
      )
      when spread in [:average, :wide] and init_closed in [:very_low, :low] and
             current_closed in [:very_high, :high] and relative_volume in [:high, :ultra_high] do
    if D.gt?(current_high, previous_high) do
      %Context{
        ctx
        | bars: [
            Bar.put_tag(current, :bottom_reversal, :assigned, current.time),
            previous_bar | rest_of_the_bars
          ]
      }
    else
      ctx
    end
  end

  def set_two_bar_tag(ctx), do: ctx

  @doc """
  (Dis)confirms a tagged bar using the following bar.

  A strength tag is confirmed when the next bar closes higher, a weakness tag when it
  closes lower. The bar's `:tag` is preserved either way; the result is recorded in
  `:status` and appended to `:tag_history`. Bars whose tag is not in the confirmation sets
  are returned unchanged.
  """
  def confirm(%Bar{tag: tag} = bar_to_confirm, %Bar{close_price: next_bar_close_price, time: at})
      when tag in @strength_tags do
    status =
      if D.gt?(next_bar_close_price, bar_to_confirm.close_price),
        do: :confirmed,
        else: :unconfirmed

    Bar.put_tag(bar_to_confirm, tag, status, at)
  end

  def confirm(%Bar{tag: tag} = bar_to_confirm, %Bar{close_price: next_bar_close_price, time: at})
      when tag in @weakness_tags do
    status =
      if D.lt?(next_bar_close_price, bar_to_confirm.close_price),
        do: :confirmed,
        else: :unconfirmed

    Bar.put_tag(bar_to_confirm, tag, status, at)
  end

  # Bars whose tag is not (yet) in the confirmation sets are left untouched.
  def confirm(%Bar{} = bar_to_confirm, _next_bar), do: bar_to_confirm

  @doc """
  Assigns a single VSA tag to `bar`, given the analysis `context`.

  Runs the ordered list of `detectors/0` and keeps the first match. Detectors are
  ordered by precedence (first match wins); the generic `professional_*` detectors
  are the fallback so that more specific principles, added over time, take
  precedence over them. Each detector returns `{:ok, tag}` or `:skip`.
  """
  def assign(%Context{} = ctx, %Bar{} = bar) do
    case run_detectors(ctx, bar) do
      nil -> bar
      tag -> Bar.put_tag(bar, tag, :assigned, bar.time)
    end
  end

  # Precedence order for single-bar detectors. New, more specific principles are
  # inserted ahead of the generic `professional_*` fallback.
  defp detectors do
    [
      &absorption_volume/2,
      &selling_climax/2,
      &buying_climax/2,
      &end_of_rising_market/2,
      &wide_spread_down_through_support/2,
      &stopping_volume/2,
      &bag_holding/2,
      &churning/2,
      &no_result_from_effort/2,
      &shakeout/2,
      &upthrust/2,
      &no_demand_at_top/2,
      &no_supply/2,
      &test/2,
      &no_demand/2,
      &professional_buying/2,
      &professional_selling/2
    ]
  end

  defp run_detectors(ctx, bar) do
    Enum.find_value(detectors(), fn detect ->
      case detect.(ctx, bar) do
        {:ok, tag} -> tag
        :skip -> nil
      end
    end)
  end

  defp professional_buying(
         %Context{volume_extreme: volume_extreme, price_low: extreme_low},
         %Bar{
           relative_volume: :ultra_high,
           direction: :down,
           close_price: close_price,
           volume: volume
         }
       ) do
    if D.compare(volume, volume_extreme) in [:gt, :eq] or D.lt?(close_price, extreme_low) do
      {:ok, :professional_buying}
    else
      :skip
    end
  end

  defp professional_buying(_ctx, _bar), do: :skip

  defp professional_selling(
         %Context{volume_extreme: volume_extreme, price_high: extreme_high},
         %Bar{
           relative_volume: :ultra_high,
           direction: :up,
           close_price: close_price,
           volume: volume
         }
       ) do
    if D.compare(volume, volume_extreme) in [:gt, :eq] or D.gt?(close_price, extreme_high) do
      {:ok, :professional_selling}
    else
      :skip
    end
  end

  defp professional_selling(_ctx, _bar), do: :skip

  defp test(
         %Context{bars: [_previous, _penultimate | _]} = ctx,
         %Bar{relative_volume: v, direction: :down, relative_spread: :narrow} = current
       )
       when v in [:low, :very_low] do
    if volume_lower_then_previous_two_bars?(ctx, current) or
         close_lower_than_previous_two_bars?(ctx, current) do
      {:ok, :test}
    else
      :skip
    end
  end

  defp test(_ctx, _bar), do: :skip

  defp no_demand(
         %Context{bars: [_previous, _penultimate | _]} = ctx,
         %Bar{relative_volume: v, direction: :up, relative_spread: :narrow} = current
       )
       when v in [:low, :very_low] do
    if volume_lower_then_previous_two_bars?(ctx, current) or
         close_higher_than_previous_two_bars?(ctx, current) do
      {:ok, :no_demand}
    else
      :skip
    end
  end

  defp no_demand(_ctx, _bar), do: :skip

  defp shakeout(
         %Context{bars: [_previous, _penultimate | _]},
         %Bar{relative_volume: v, direction: :down, closed: c, opened: o, relative_spread: spread}
       )
       when v not in [:low, :very_low] and c in [:high, :very_high] and o in [:high, :very_high] and
              spread in [:average, :wide] do
    {:ok, :shakeout}
  end

  defp shakeout(_ctx, _bar), do: :skip

  defp upthrust(
         %Context{bars: [_previous, _penultimate | _]},
         %Bar{relative_volume: v, direction: :down, closed: c, opened: o, relative_spread: spread}
       )
       when v not in [:low, :very_low] and c in [:low, :very_low] and o in [:low] and
              spread in [:average, :wide] do
    {:ok, :upthrust}
  end

  defp upthrust(_ctx, _bar), do: :skip

  # --- Signs of strength / weakness derived from VSA primitives ---
  # Any trend/location these need comes from injected per-bar context when present
  # (`bar.trend`) or a local multi-bar proxy; the library never computes trend.

  defp selling_climax(
         %Context{thresholds: %{climax_close_min_position: min_pos}} = ctx,
         %Bar{direction: :down, relative_volume: :ultra_high, relative_spread: :wide} = bar
       ) do
    pos = close_position(bar)

    if not is_nil(pos) and D.compare(pos, min_pos) in [:gt, :eq] and downtrend_context?(ctx, bar) do
      {:ok, :selling_climax}
    else
      :skip
    end
  end

  defp selling_climax(_ctx, _bar), do: :skip

  defp buying_climax(
         %Context{thresholds: %{buying_climax_close_max_position: max_pos}} = ctx,
         %Bar{direction: :up, relative_volume: :ultra_high, relative_spread: :wide} = bar
       ) do
    pos = close_position(bar)

    if not is_nil(pos) and D.compare(pos, max_pos) in [:lt, :eq] and fresh_high_ground?(ctx, bar) do
      {:ok, :buying_climax}
    else
      :skip
    end
  end

  defp buying_climax(_ctx, _bar), do: :skip

  defp end_of_rising_market(
         %Context{thresholds: %{buying_climax_close_max_position: max_pos}} = ctx,
         %Bar{direction: :up, relative_volume: rv, relative_spread: :narrow} = bar
       )
       when rv in [:high, :ultra_high] do
    pos = close_position(bar)

    if not is_nil(pos) and D.compare(pos, max_pos) in [:lt, :eq] and fresh_high_ground?(ctx, bar) do
      {:ok, :end_of_rising_market}
    else
      :skip
    end
  end

  defp end_of_rising_market(_ctx, _bar), do: :skip

  # Stopping volume: high/ultra-high volume down bar whose spread narrows versus the
  # prior bar and which closes off the low, during a down move. Demand absorbing supply.
  defp stopping_volume(
         %Context{bars: [%Bar{spread: prev_spread} | _]} = ctx,
         %Bar{
           direction: :down,
           relative_volume: rv,
           relative_spread: rs,
           closed: c,
           spread: spread
         } = bar
       )
       when rv in [:high, :ultra_high] and rs in [:narrow, :average] and
              c in [:middle, :high, :very_high] do
    if D.lt?(spread, prev_spread) and downtrend_context?(ctx, bar) do
      {:ok, :stopping_volume}
    else
      :skip
    end
  end

  defp stopping_volume(_ctx, _bar), do: :skip

  # Bag holding (two-bar stopping volume): a prior bar of heavy supply, then this bar
  # pushes to a new low (bad news) yet closes in the middle/high — demand has overcome
  # the supply, marking the bottom. (current = arg 2, prior = ctx.bars head.)
  defp bag_holding(
         %Context{bars: [%Bar{relative_volume: prev_rv, low: prev_low} | _]},
         %Bar{direction: :down, low: cur_low, closed: closed}
       )
       when prev_rv in [:high, :ultra_high] and closed in [:middle, :high, :very_high] do
    if D.lt?(cur_low, prev_low), do: {:ok, :bag_holding}, else: :skip
  end

  defp bag_holding(_ctx, _bar), do: :skip

  # Churning: ultra-high volume on a narrow spread following another high-volume bar —
  # lots of activity, no progress.
  defp churning(
         %Context{bars: [%Bar{relative_volume: prev_rv} | _]},
         %Bar{relative_volume: :ultra_high, relative_spread: :narrow}
       )
       when prev_rv in [:high, :ultra_high] do
    {:ok, :churning}
  end

  defp churning(_ctx, _bar), do: :skip

  # No result from effort: an effort to rise (up bars on rising volume) answered by a
  # wide-spread down bar closing on its low, below the prior bar.
  defp no_result_from_effort(
         %Context{bars: [prev | _]} = ctx,
         %Bar{direction: :down, relative_spread: :wide, closed: c, low: low, close_price: close}
       )
       when c in [:low, :very_low] do
    if effort_to_rise?(ctx) and D.lt?(low, prev.low) and D.lt?(close, prev.close_price) do
      {:ok, :no_result_from_effort}
    else
      :skip
    end
  end

  defp no_result_from_effort(_ctx, _bar), do: :skip

  # No supply: the Test, but with strength already in the background — a down bar on
  # volume lower than the prior two showing the lack of selling pressure.
  defp no_supply(
         %Context{bars: [_previous, _penultimate | _], background: :strength} = ctx,
         %Bar{relative_volume: v, direction: :down, relative_spread: :narrow} = current
       )
       when v in [:low, :very_low] do
    if volume_lower_then_previous_two_bars?(ctx, current) do
      {:ok, :no_supply}
    else
      :skip
    end
  end

  defp no_supply(_ctx, _bar), do: :skip

  # --- Location-dependent principles. These need support/resistance levels, which
  # the caller supplies per bar (`bar.levels`); with no levels they never fire. ---

  # Absorption volume: the documented exception to "wide high-volume up bar = weakness".
  # A wide up bar closing on its high that pushes up through an old resistance the
  # previous bar had not cleared.
  defp absorption_volume(
         %Context{bars: [%Bar{close_price: prev_close} | _]},
         %Bar{
           direction: :up,
           relative_volume: rv,
           relative_spread: :wide,
           closed: c,
           close_price: close,
           levels: levels
         }
       )
       when rv in [:high, :ultra_high] and c in [:high, :very_high] do
    case nearest_resistance_below(levels, close) do
      %VSA.Level{price: level} ->
        if D.gt?(close, level) and not D.gt?(prev_close, level),
          do: {:ok, :absorption_volume},
          else: :skip

      nil ->
        :skip
    end
  end

  defp absorption_volume(_ctx, _bar), do: :skip

  # Wide-spread down bar through previous support: a wide down bar closing on its low
  # that breaks down through an old support the previous bar held above.
  defp wide_spread_down_through_support(
         %Context{bars: [%Bar{close_price: prev_close} | _]},
         %Bar{
           direction: :down,
           relative_spread: :wide,
           closed: c,
           close_price: close,
           levels: levels
         }
       )
       when c in [:low, :very_low] do
    case nearest_support_above(levels, close) do
      %VSA.Level{price: level} ->
        if D.lt?(close, level) and not D.lt?(prev_close, level),
          do: {:ok, :wide_spread_down_through_support},
          else: :skip

      nil ->
        :skip
    end
  end

  defp wide_spread_down_through_support(_ctx, _bar), do: :skip

  # No demand at a market top: a No Demand up bar whose high sits at an old resistance.
  defp no_demand_at_top(
         %Context{
           bars: [_previous, _penultimate | _],
           mean_spread: mean_spread,
           thresholds: %{level_proximity_factor: factor}
         } = ctx,
         %Bar{
           relative_volume: v,
           direction: :up,
           relative_spread: :narrow,
           high: high,
           levels: levels
         } =
           current
       )
       when v in [:low, :very_low] do
    tolerance = D.mult(factor, mean_spread)

    no_demand? =
      volume_lower_then_previous_two_bars?(ctx, current) or
        close_higher_than_previous_two_bars?(ctx, current)

    if near_resistance?(levels, high, tolerance) and no_demand? do
      {:ok, :no_demand_at_top}
    else
      :skip
    end
  end

  defp no_demand_at_top(_ctx, _bar), do: :skip

  # --- shared helpers for the detectors above ---

  defp close_position(%Bar{high: high, low: low, close_price: close}) do
    spread = D.sub(high, low)
    if D.gt?(spread, @zero), do: D.div(D.sub(close, low), spread), else: nil
  end

  defp fresh_high_ground?(%Context{price_high: price_high}, %Bar{high: high}) do
    D.gt?(price_high, @zero) and D.gt?(high, price_high)
  end

  defp downtrend_context?(_ctx, %Bar{trend: :down}), do: true
  defp downtrend_context?(%Context{} = ctx, %Bar{}), do: recent_downmove?(ctx)

  defp recent_downmove?(%Context{bars: bars}) do
    bars |> Enum.take(3) |> Enum.count(&(&1.direction == :down)) >= 2
  end

  defp effort_to_rise?(%Context{
         bars: [prev, penult | _],
         thresholds: %{effort_volume_step: step}
       }) do
    prev.direction == :up and penult.direction == :up and
      D.gt?(prev.volume, D.mult(step, penult.volume))
  end

  defp effort_to_rise?(_ctx), do: false

  # The highest resistance strictly below `close` (the one just broken through).
  defp nearest_resistance_below(levels, close) do
    levels
    |> Enum.filter(fn %VSA.Level{kind: kind, price: price} ->
      kind == :resistance and D.lt?(price, close)
    end)
    |> case do
      [] -> nil
      candidates -> Enum.max_by(candidates, & &1.price, Decimal)
    end
  end

  # The lowest support strictly above `close` (the one just broken down through).
  defp nearest_support_above(levels, close) do
    levels
    |> Enum.filter(fn %VSA.Level{kind: kind, price: price} ->
      kind == :support and D.gt?(price, close)
    end)
    |> case do
      [] -> nil
      candidates -> Enum.min_by(candidates, & &1.price, Decimal)
    end
  end

  defp near_resistance?(levels, price, tolerance) do
    Enum.any?(levels, fn
      %VSA.Level{kind: :resistance, price: level} ->
        D.compare(D.abs(D.sub(price, level)), tolerance) in [:lt, :eq]

      _ ->
        false
    end)
  end

  defp volume_lower_then_previous_two_bars?(%Context{bars: [previous, penultimate | _]}, %Bar{
         volume: volume
       }) do
    D.lt?(volume, previous.volume) && D.lt?(volume, penultimate.volume)
  end

  defp close_lower_than_previous_two_bars?(%Context{bars: [previous, penultimate | _]}, %Bar{
         close_price: close_price
       }) do
    D.lt?(close_price, previous.close_price) && D.lt?(close_price, penultimate.close_price)
  end

  defp close_higher_than_previous_two_bars?(%Context{bars: [previous, penultimate | _]}, %Bar{
         close_price: close_price
       }) do
    D.gt?(close_price, previous.close_price) && D.gt?(close_price, penultimate.close_price)
  end
end
