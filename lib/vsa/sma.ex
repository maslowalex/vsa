defmodule VSA.SMA do
  @moduledoc """
  Simple moving average implementation
  """

  @period 21

  def latest([%{sma: _} | _] = bars, incoming_close_price) do
    bars = [
      Decimal.to_float(incoming_close_price) | Enum.map(bars, &Decimal.to_float(&1.close_price))
    ]

    TAlib.Indicators.MA.sma(bars, @period)
  end
end
