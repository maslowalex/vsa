defmodule VSA.Setup do
  @moduledoc """
  A trade thesis built from a primary VSA event and the secondary events that validate it.

  A setup is **anchored** by a primary turning-point bar and then **confirmed** by secondary
  bars that fall in the same direction (polarity). Each principle plays exactly one role:

  ## Anchors (start / replace a setup)

  These are the climactic and reversal principles — the bars that mark a top or a bottom.
  The latest anchor bar wins, so a fresh climax replaces an older setup (and an opposite-
  polarity anchor flips the regime).

    * Strength (mark a bottom): `:professional_buying`, `:bottom_reversal`,
      `:selling_climax`, `:bag_holding`
    * Weakness (mark a top): `:professional_selling`, `:top_reversal`, `:buying_climax`,
      `:end_of_rising_market`

  ## Confirmations (append to the active setup)

  The secondary signals. They are only meaningful relative to an existing setup of the same
  polarity; a confirmation against an opposite-polarity setup is ignored.

    * Strength: `:test`, `:shakeout`, `:no_supply`, `:stopping_volume`, `:absorption_volume`
    * Weakness: `:no_demand`, `:upthrust`, `:no_demand_at_top`,
      `:wide_spread_down_through_support`, `:no_result_from_effort`, `:churning`

  The Test-like confirmations (`:test`/`:no_supply` for strength, `:no_demand`/
  `:no_demand_at_top` for weakness) must *penetrate* the setup area — close above the setup
  high (strength) or below the setup low (weakness). The remaining confirmations are
  structural follow-through and are recorded regardless of close price (as `:shakeout` /
  `:upthrust` always were).

  Two cross-polarity exceptions are kept: an *unconfirmed* `:no_demand` (a weakness signal
  that failed) pushing above a strength setup's high is itself strength; symmetrically an
  *unconfirmed* `:test` breaking below a weakness setup's low confirms weakness.
  """

  alias VSA.Bar
  alias VSA.Context

  @derive JSON.Encoder
  defstruct [
    :principle,
    :volume,
    :high,
    :low,
    :close_price,
    :inception_time,
    confirmations: []
  ]

  @strength_anchors [:professional_buying, :bottom_reversal, :selling_climax, :bag_holding]
  @weakness_anchors [:professional_selling, :top_reversal, :buying_climax, :end_of_rising_market]

  @strength_confirmations [:test, :shakeout, :no_supply, :stopping_volume, :absorption_volume]
  @weakness_confirmations [
    :no_demand,
    :upthrust,
    :no_demand_at_top,
    :wide_spread_down_through_support,
    :no_result_from_effort,
    :churning
  ]

  # Confirmations that must penetrate the setup area (vs. structural follow-through).
  @strength_penetration [:test, :no_supply]
  @weakness_penetration [:no_demand, :no_demand_at_top]

  @doc """
  The polarity of an anchor principle: `:strength`, `:weakness`, or `:neutral`.

  Reused by `VSA.Context.set_background/1` so the background regime and the setup layer
  share one classification.
  """
  def anchor_polarity(tag) when tag in @strength_anchors, do: :strength
  def anchor_polarity(tag) when tag in @weakness_anchors, do: :weakness
  def anchor_polarity(_tag), do: :neutral

  def tested?(%VSA.Setup{confirmations: []}), do: false
  def tested?(%VSA.Setup{}), do: true

  # --- Anchors: a primary bar starts (or replaces) the setup. ---

  def capture(%Context{bars: [%Bar{tag: tag} = bar | _]}) when tag in @strength_anchors do
    new_setup(bar, tag)
  end

  def capture(%Context{bars: [%Bar{tag: tag} = bar | _]}) when tag in @weakness_anchors do
    new_setup(bar, tag)
  end

  # --- Cross-polarity exceptions: a failed (unconfirmed) signal that pierces the opposite
  # side of the setup area confirms the setup. Must precede the generic confirmation clause. ---

  def capture(%Context{
        bars: [%Bar{tag: :no_demand, status: :unconfirmed} = bar | _],
        setup: %VSA.Setup{principle: principle} = setup
      })
      when principle in @strength_anchors do
    if Decimal.gt?(bar.close_price, setup.high), do: append(setup, bar), else: setup
  end

  def capture(%Context{
        bars: [%Bar{tag: :test, status: :unconfirmed} = bar | _],
        setup: %VSA.Setup{principle: principle} = setup
      })
      when principle in @weakness_anchors do
    if Decimal.lt?(bar.close_price, setup.low), do: append(setup, bar), else: setup
  end

  # --- Confirmations: a secondary bar matching the active setup's polarity. ---

  def capture(%Context{bars: [%Bar{tag: tag} = bar | _], setup: %VSA.Setup{} = setup})
      when tag in @strength_confirmations or tag in @weakness_confirmations do
    maybe_confirm(setup, bar, tag)
  end

  def capture(%Context{setup: setup}), do: setup

  defp new_setup(%Bar{} = bar, principle) do
    %VSA.Setup{
      principle: principle,
      volume: bar.volume,
      high: bar.high,
      low: bar.low,
      close_price: bar.close_price,
      inception_time: bar.time
    }
  end

  defp maybe_confirm(%VSA.Setup{principle: principle} = setup, bar, tag) do
    case anchor_polarity(principle) do
      :strength when tag in @strength_confirmations ->
        add_confirmation(setup, bar, tag, :strength)

      :weakness when tag in @weakness_confirmations ->
        add_confirmation(setup, bar, tag, :weakness)

      _ ->
        setup
    end
  end

  # Test-like confirmations must penetrate the setup area; the rest are unconditional.
  defp add_confirmation(setup, bar, tag, :strength) when tag in @strength_penetration do
    if Decimal.gt?(bar.close_price, setup.high), do: append(setup, bar), else: setup
  end

  defp add_confirmation(setup, bar, tag, :weakness) when tag in @weakness_penetration do
    if Decimal.lt?(bar.close_price, setup.low), do: append(setup, bar), else: setup
  end

  defp add_confirmation(setup, bar, _tag, _polarity), do: append(setup, bar)

  defp append(%VSA.Setup{} = setup, bar) do
    %VSA.Setup{setup | confirmations: [take_essential_bar_info(bar) | setup.confirmations]}
  end

  defp take_essential_bar_info(bar) do
    Map.take(bar, [
      :tag,
      :status,
      :close_price,
      :volume,
      :time,
      :relative_volume,
      :relative_spread
    ])
  end
end
