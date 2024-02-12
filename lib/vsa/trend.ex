defmodule VSA.Trend do
  @moduledoc """
  Analyze the trend of market based on

  EMA with period 10
  SMA with period of 21
  Closing price
  """

  alias VSA.Context

  def evaluate(_, _close, sma, ema) when is_nil(sma) or is_nil(ema), do: :flat

  def evaluate(%Context{bars: [%{trend: :down} | _]}, close, sma, ema)
      when close > sma and close > ema and sma > ema,
      do: :flat

  def evaluate(%Context{bars: [%{trend: :flat} | _]}, close, sma, ema)
      when close > sma and close > ema and sma > ema,
      do: :up

  def evaluate(_, close, sma, ema)
      when close > sma and close > ema and sma > ema,
      do: :up

  def evaluate(%Context{bars: [%{trend: :up} | _]}, close, sma, ema)
      when close < sma and close < ema and sma < ema,
      do: :flat

  def evaluate(_, close, sma, ema)
      when close < sma and close < ema and sma < ema,
      do: :down

  def evaluate(_, close, sma, ema) do
    :down
  end
end
