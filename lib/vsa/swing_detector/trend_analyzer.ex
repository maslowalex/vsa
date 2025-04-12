defmodule VSA.SwingDetector.TrendAnalyzer do
  @moduledoc """
  Analyzes swing points to identify trends in market data.
  """

  defmodule Trend do
    @moduledoc """
    Represents a detected trend in the market.
    """
    defstruct [
      # :uptrend, :downtrend, or :ranging
      :type,
      # Starting bar index
      :start_index,
      # Ending bar index
      :end_index,
      # Price at start
      :start_price,
      # Price at end
      :end_price,
      # List of swing points within this trend
      :swing_points,
      # Strength indicator (can be calculated various ways)
      :strength,
      # Number of bars the trend lasted
      :duration
    ]
  end

  @doc """
  Analyzes swing highs and lows to identify trends.
  Returns a list of Trend structs ordered chronologically.
  """
  def analyze_trends(swing_highs, swing_lows) do
    # 1. Combine all swing points and sort chronologically
    all_points =
      (Enum.map(swing_highs, fn {idx, price} -> {:high, idx, price} end) ++
         Enum.map(swing_lows, fn {idx, price} -> {:low, idx, price} end))
      |> Enum.sort_by(fn {_, idx, _} -> idx end)

    # 2. Now identify trends based on the sequence of highs and lows
    {trends, _} = identify_trends(all_points, [], nil, nil)

    trends
  end

  @doc """
  Updates the trend based on the latest swing points.
  """
  def update_trend(trends, {_, _idx, _price} = new_swing_point) do
    current_trend = List.last(trends)
    prev_point = List.last(current_trend.swing_points)

    {trends, _} = identify_trends([new_swing_point], trends, current_trend, prev_point)

    trends
  end

  defp identify_trends([], trends, current_trend, _) do
    final_trends = if current_trend, do: [current_trend | trends], else: trends
    {Enum.reverse(final_trends), nil}
  end

  defp identify_trends([point | rest], trends, nil, nil) do
    # First point - can't determine trend yet
    identify_trends(rest, trends, nil, point)
  end

  defp identify_trends([point | rest], trends, nil, prev_point) do
    # Second point - now we can determine initial trend
    {type, prev_idx, prev_price} = prev_point
    {type2, idx, price} = point

    # Create initial trend
    trend =
      cond do
        type == :low && type2 == :high ->
          # Rising from low to high - uptrend
          %Trend{
            type: :uptrend,
            start_index: prev_idx,
            end_index: idx,
            start_price: prev_price,
            end_price: price,
            swing_points: [prev_point, point],
            strength: calc_strength(:uptrend, prev_price, price),
            duration: idx - prev_idx
          }

        type == :high && type2 == :low ->
          # Falling from high to low - downtrend
          %Trend{
            type: :downtrend,
            start_index: prev_idx,
            end_index: idx,
            start_price: prev_price,
            end_price: price,
            swing_points: [prev_point, point],
            strength: calc_strength(:downtrend, prev_price, price),
            duration: idx - prev_idx
          }

        true ->
          # Same type points in a row - need more data
          nil
      end

    identify_trends(rest, trends, trend, point)
  end

  defp identify_trends([point | rest], trends, current_trend, prev_point) do
    {type, idx, price} = point

    {continuation_trend, new_trend} =
      cond do
        current_trend.type == :uptrend && type == :high && price > current_trend.end_price ->
          # Higher high in an uptrend - continue uptrend
          {%{
             current_trend
             | end_index: idx,
               end_price: price,
               swing_points: current_trend.swing_points ++ [point],
               strength: calc_strength(:uptrend, current_trend.start_price, price),
               duration: idx - current_trend.start_index
           }, nil}

        current_trend.type == :uptrend && type == :low ->
          # Low after uptrend - potential reversal
          # Check if it's lower than the previous low point
          prev_low =
            Enum.find(
              Enum.reverse(current_trend.swing_points),
              fn {t, _, _} -> t == :low end
            )

          if prev_low && elem(prev_low, 2) > price do
            # Lower low - confirms downtrend reversal
            {nil,
             %Trend{
               type: :downtrend,
               start_index: elem(prev_point, 1),
               end_index: idx,
               start_price: elem(prev_point, 2),
               end_price: price,
               swing_points: [prev_point, point],
               strength: calc_strength(:downtrend, elem(prev_point, 2), price),
               duration: idx - elem(prev_point, 1)
             }}
          else
            # Not a lower low - could be pullback in uptrend
            {%{current_trend | swing_points: current_trend.swing_points ++ [point]}, nil}
          end

        current_trend.type == :downtrend && type == :low && price < current_trend.end_price ->
          # Lower low in downtrend - continue downtrend
          {%{
             current_trend
             | end_index: idx,
               end_price: price,
               swing_points: current_trend.swing_points ++ [point],
               strength: calc_strength(:downtrend, current_trend.start_price, price),
               duration: idx - current_trend.start_index
           }, nil}

        current_trend.type == :downtrend && type == :high ->
          # High after downtrend - potential reversal
          # Check if it's higher than the previous high point
          prev_high =
            Enum.find(
              Enum.reverse(current_trend.swing_points),
              fn {t, _, _} -> t == :high end
            )

          if prev_high && elem(prev_high, 2) < price do
            # Higher high - confirms uptrend reversal
            {nil,
             %Trend{
               type: :uptrend,
               start_index: elem(prev_point, 1),
               end_index: idx,
               start_price: elem(prev_point, 2),
               end_price: price,
               swing_points: [prev_point, point],
               strength: calc_strength(:uptrend, elem(prev_point, 2), price),
               duration: idx - elem(prev_point, 1)
             }}
          else
            # Not a higher high - could be retracement in downtrend
            {%{current_trend | swing_points: current_trend.swing_points ++ [point]}, nil}
          end

        true ->
          # Continue current trend with new point
          {%{current_trend | swing_points: current_trend.swing_points ++ [point]}, nil}
      end

    if new_trend do
      # We have a new trend, so add the current one to our list
      identify_trends(rest, [current_trend | trends], new_trend, point)
    else
      # Continue with the updated trend
      identify_trends(rest, trends, continuation_trend, point)
    end
  end

  # Calculates trend strength based on price movement.
  # Could be enhanced with more sophisticated metrics.
  defp calc_strength(:uptrend, start_price, end_price) do
    # For simplicity, using percentage change
    # This could be enhanced with more sophisticated metrics
    decimal_change = Decimal.sub(end_price, start_price)
    Decimal.div(decimal_change, start_price)
  end

  defp calc_strength(:downtrend, start_price, end_price) do
    # For downtrends, we use absolute value of percentage change
    decimal_change = Decimal.sub(start_price, end_price)
    Decimal.div(decimal_change, start_price)
  end

  @doc """
  Provides a summary of detected trends.
  """
  def summarize_trends(trends) do
    Enum.map(trends, fn trend ->
      trend_str =
        case trend.type do
          :uptrend -> "UPTREND"
          :downtrend -> "DOWNTREND"
          _ -> "RANGING"
        end

      strength_pct = Decimal.mult(trend.strength, Decimal.new(100))

      "#{trend_str}: Bars #{trend.start_index}-#{trend.end_index} (#{trend.duration} bars), " <>
        "Price #{trend.start_price} -> #{trend.end_price} (#{Decimal.round(strength_pct, 2)}%)"
    end)
  end

  @doc """
  Determines the overall market trend based on the most recent trends.
  """
  def overall_trend(trends, lookback \\ 3) do
    recent_trends = Enum.take(trends, lookback)

    {uptrend_count, downtrend_count} =
      Enum.reduce(recent_trends, {0, 0}, fn trend, {up, down} ->
        case trend.type do
          :uptrend -> {up + 1, down}
          :downtrend -> {up, down + 1}
          _ -> {up, down}
        end
      end)

    cond do
      uptrend_count > downtrend_count -> :uptrend
      downtrend_count > uptrend_count -> :downtrend
      true -> :ranging
    end
  end
end
