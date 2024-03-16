defmodule VSA.EMA do
  @moduledoc """
  Exponential moving average implementation.

  Courtesy of Indicado library.
  """

  @period 9

  def latest([%{ema: nil} | _] = bars, incoming_close_price) do
    bars = [
      Decimal.to_float(incoming_close_price) | Enum.map(bars, &Decimal.to_float(&1.close_price))
    ]

    TAlib.Indicators.MA.ema(bars, @period)
  end

  def latest([%{ema: ema} | _], incoming_close_price) do
    TAlib.Indicators.MA.update_ema(ema, Decimal.to_float(incoming_close_price), @period)
  end
end
