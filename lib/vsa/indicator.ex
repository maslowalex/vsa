defmodule VSA.Indicator do
  @moduledoc """
  Module that is responsible to assign an indicator to individual bar.
  """

  alias Decimal, as: D

  alias VSA.Bar
  alias VSA.Context

  def confirm(%Bar{tag: tag} = bar_to_confirm, next_bar_close_price)
      when tag in [:shakeout, :test] do
    if D.gt?(next_bar_close_price, bar_to_confirm.close_price) do
      bar_to_confirm
    else
      %Bar{bar_to_confirm | tag: :"unconfirmed_#{tag}"}
    end
  end

  def confirm(%Bar{tag: tag} = bar_to_confirm, next_bar_close_price)
      when tag in [:no_demand, :upthrust] do
    if D.lt?(next_bar_close_price, bar_to_confirm.close_price) do
      bar_to_confirm
    else
      %Bar{bar_to_confirm | tag: :"unconfirmed_#{tag}"}
    end
  end

  @doc """
  Assigns an indicator to the given bar.
  """
  def assign(
        %Context{bars: [_previous, _penultimate | _]} = ctx,
        %Bar{relative_volume: v, direction: :down, relative_spread: :narrow} = current
      )
      when v in [:low, :very_low] do
    if volume_lower_then_previous_two_bars?(ctx, current) do
      %Bar{current | tag: :test}
    else
      current
    end
  end

  def assign(
        %Context{bars: [_previous, _penultimate | _]} = ctx,
        %Bar{relative_volume: v, direction: :up, relative_spread: :narrow} = current
      )
      when v in [:low, :very_low] do
    if volume_lower_then_previous_two_bars?(ctx, current) do
      %Bar{current | tag: :no_demand}
    else
      current
    end
  end

  def assign(
        %Context{bars: [_previous, _penultimate | _]},
        %Bar{relative_volume: v, direction: :down, closed: c, opened: o, relative_spread: spread} =
          current
      )
      when v not in [:low, :very_low] and c in [:high, :very_high] and o in [:high, :very_high] and
             spread in [:average, :wide] do
    %Bar{current | tag: :shakeout}
  end

  def assign(
        %Context{bars: [_previous, _penultimate | _]},
        %Bar{relative_volume: v, direction: :down, closed: c, opened: o, relative_spread: spread} =
          current
      )
      when v not in [:low, :very_low] and c in [:low, :very_low] and o in [:low] and
             spread in [:average, :wide] do
    %Bar{current | tag: :upthrust}
  end

  def assign(_, bar), do: bar

  defp volume_lower_then_previous_two_bars?(%Context{bars: [previous, penultimate | _]}, %Bar{
         volume: volume
       }) do
    D.lt?(volume, previous.volume) && D.lt?(volume, penultimate.volume)
  end
end
