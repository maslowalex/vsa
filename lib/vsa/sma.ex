defmodule VSA.Sma do
  @moduledoc """
  Simple moving average implementation
  """

  @period 20

  @spec evaluate(nonempty_list(Decimal.t())) :: {:ok, list(Decimal.t())} | {:error, atom()}
  def evaluate(list) do
    calc(list, @period, [])
  end

  @spec latest(list(Decimal.t())) :: Decimal.t() | nil
  def latest(list) do
    case calc(list, @period, []) do
      {:ok, [head | _tail]} -> head
      _ -> nil
    end
  end

  defp calc(list, period, results)

  defp calc([], _period, []), do: {:error, :not_enough_data}

  defp calc(_list, period, _results) when period < 1, do: {:error, :bad_period}

  defp calc([], _period, results), do: {:ok, Enum.reverse(results)}

  defp calc([_head | tail] = list, period, results) when length(list) < period do
    calc(tail, period, results)
  end

  defp calc([_head | tail] = list, period, results) do
    avg =
      list
      |> Enum.take(period)
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&1, &2))
      |> Decimal.div(period)

    calc(tail, period, [avg | results])
  end
end
