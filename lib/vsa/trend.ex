defmodule VSA.Trend do
  @moduledoc """
  Analyze the trend of market based on

  EMA with period 10
  SMA with period of 21
  Closing price
  """

  def evaluate(_, _close, sma, ema) when is_nil(sma) or is_nil(ema), do: :flat

  def evaluate(_, close, sma, ema) when close >= sma and ema >= sma, do: :up

  def evaluate(_, close, sma, ema) when close <= sma and ema <= sma, do: :down

  def evaluate(_, _close, _sma, _ema), do: :flat
end
