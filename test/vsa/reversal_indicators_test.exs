defmodule VSA.ReversalIndicatorsTest do
  use ExUnit.Case
  doctest Vsa.Tag

  alias VSA.{Bar, Context}
  alias Decimal, as: D

  describe "Top reversal indicator" do
    test "identifies top reversal pattern correctly" do
      # Current bar: DOWN bar with wide spread that closes on low and is lower than previous bar's low
      current_bar = %Bar{
        direction: :down,
        closed: :very_low,
        high: D.new("103"),
        low: D.new("95"),
        close_price: D.new("95"),
        volume: D.new("1200"),
        spread: D.new("8"),
        time: ~U[2023-01-01 11:00:00Z],
        relative_volume: :high,
        relative_spread: :wide,
        tag: nil,
        finished: true,
        opened: nil
      }

      # Previous bar: UP bar that closes on high and forms new price_high
      previous_bar = %Bar{
        direction: :up,
        closed: :very_high,
        high: D.new("105"),
        low: D.new("100"),
        close_price: D.new("105"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        relative_volume: :ultra_high,
        relative_spread: :wide,
        tag: nil,
        finished: true,
        opened: nil
      }

      context = %Context{
        bars: [current_bar, previous_bar],
        price_high: D.new("105"),
        price_high_set_bars_ago: 0,
        price_low: D.new("90"),
        price_low_set_bars_ago: 10,
        volume_extreme: D.new("1500"),
        volume_extreme_set_bars_ago: 5,
        bars_to_mean: 50,
        max_bars: 200,
        setup: nil,
        mean_vol: D.new("800"),
        mean_spread: D.new("4")
      }

      result = Vsa.Tag.set_two_bar_tag(context)

      assert List.first(result.bars).tag == :top_reversal
    end

    test "doesn't identify top reversal if the price isn't in new fresh ground" do
      # Current bar: DOWN bar with wide spread that closes on low and is lower than previous bar's low
      current_bar = %Bar{
        direction: :down,
        closed: :very_low,
        high: D.new("103"),
        low: D.new("95"),
        close_price: D.new("95"),
        volume: D.new("1200"),
        spread: D.new("8"),
        time: ~U[2023-01-01 11:00:00Z],
        relative_volume: :high,
        relative_spread: :wide,
        tag: nil,
        finished: true,
        opened: nil
      }

      # Previous bar: UP bar that closes on high and forms new price_high
      previous_bar = %Bar{
        direction: :up,
        closed: :very_high,
        high: D.new("105"),
        low: D.new("100"),
        close_price: D.new("105"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        relative_volume: :average,
        relative_spread: :wide,
        tag: nil,
        finished: true,
        opened: nil
      }

      context = %Context{
        bars: [current_bar, previous_bar],
        price_high: D.new("105"),
        price_high_set_bars_ago: 10,
        price_low: D.new("90"),
        price_low_set_bars_ago: 10,
        volume_extreme: D.new("1500"),
        volume_extreme_set_bars_ago: 5,
        bars_to_mean: 50,
        max_bars: 200,
        setup: nil,
        mean_vol: D.new("800"),
        mean_spread: D.new("4")
      }

      result = Vsa.Tag.set_two_bar_tag(context)

      assert List.first(result.bars).tag == nil
    end

    test "does not identify top reversal when previous bar doesn't close on high" do
      current_bar = %Bar{
        direction: :down,
        closed: :very_low,
        high: D.new("103"),
        low: D.new("95"),
        close_price: D.new("95"),
        volume: D.new("1200"),
        spread: D.new("8"),
        time: ~U[2023-01-01 11:00:00Z],
        relative_volume: :high,
        relative_spread: :wide,
        tag: nil,
        finished: true,
        opened: nil
      }

      # Previous bar not closing on high
      previous_bar = %Bar{
        direction: :up,
        closed: :middle,
        high: D.new("105"),
        low: D.new("100"),
        close_price: D.new("102"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        relative_volume: :average,
        relative_spread: :average,
        tag: nil,
        finished: true,
        opened: nil
      }

      context = %Context{
        bars: [current_bar, previous_bar],
        price_high: D.new("105"),
        price_high_set_bars_ago: 0,
        price_low: D.new("90"),
        price_low_set_bars_ago: 10,
        volume_extreme: D.new("1500"),
        volume_extreme_set_bars_ago: 5,
        bars_to_mean: 50,
        max_bars: 200,
        setup: nil,
        mean_vol: D.new("800"),
        mean_spread: D.new("4")
      }

      result = Vsa.Tag.set_two_bar_tag(context)

      assert List.first(result.bars).tag == nil
    end

    test "does not identify top reversal when current bar low is not lower than previous bar low" do
      # Current bar with low higher than previous bar's low
      current_bar = %Bar{
        direction: :down,
        closed: :very_low,
        high: D.new("103"),
        low: D.new("101"),
        close_price: D.new("101"),
        volume: D.new("1200"),
        spread: D.new("2"),
        time: ~U[2023-01-01 11:00:00Z],
        relative_volume: :high,
        relative_spread: :average,
        tag: nil,
        finished: true,
        opened: nil
      }

      previous_bar = %Bar{
        direction: :up,
        closed: :very_high,
        high: D.new("105"),
        low: D.new("100"),
        close_price: D.new("105"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        relative_volume: :average,
        relative_spread: :average,
        tag: nil,
        finished: true,
        opened: nil
      }

      context = %Context{
        bars: [current_bar, previous_bar],
        price_high: D.new("105"),
        price_high_set_bars_ago: 0,
        price_low: D.new("90"),
        price_low_set_bars_ago: 10,
        volume_extreme: D.new("1500"),
        volume_extreme_set_bars_ago: 5,
        bars_to_mean: 50,
        max_bars: 200,
        setup: nil,
        mean_vol: D.new("800"),
        mean_spread: D.new("4")
      }

      result = Vsa.Tag.set_two_bar_tag(context)

      assert List.first(result.bars).tag == nil
    end
  end

  describe "Bottom reversal indicator" do
    test "identifies bottom reversal pattern correctly" do
      # Current bar: UP bar with wide spread that closes on high and is higher than previous bar's high
      current_bar = %Bar{
        direction: :up,
        closed: :very_high,
        high: D.new("105"),
        low: D.new("97"),
        close_price: D.new("105"),
        volume: D.new("1200"),
        spread: D.new("8"),
        time: ~U[2023-01-01 11:00:00Z],
        relative_volume: :high,
        relative_spread: :wide,
        tag: nil,
        finished: true
      }

      # Previous bar: DOWN bar that closes on low and forms new price_low
      previous_bar = %Bar{
        direction: :down,
        closed: :very_low,
        high: D.new("100"),
        low: D.new("95"),
        close_price: D.new("95"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        relative_volume: :high,
        relative_spread: :wide,
        tag: nil,
        finished: true
      }

      context = %Context{
        bars: [current_bar, previous_bar],
        price_low: D.new("95"),
        price_low_set_bars_ago: 0,
        mean_vol: D.new("800"),
        mean_spread: D.new("4")
      }

      result = Vsa.Tag.set_two_bar_tag(context)

      assert List.first(result.bars).tag == :bottom_reversal
    end

    test "does not identify bottom reversal when previous bar doesn't close on low" do
      current_bar = %Bar{
        direction: :up,
        closed: :very_high,
        high: D.new("105"),
        low: D.new("97"),
        close_price: D.new("105"),
        volume: D.new("1200"),
        spread: D.new("8"),
        time: ~U[2023-01-01 11:00:00Z],
        relative_volume: :high,
        relative_spread: :wide,
        tag: nil,
        finished: true
      }

      # Previous bar not closing on low
      previous_bar = %Bar{
        direction: :down,
        closed: :middle,
        high: D.new("100"),
        low: D.new("95"),
        close_price: D.new("97"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        relative_volume: :average,
        relative_spread: :average,
        tag: nil,
        finished: true
      }

      context = %Context{
        bars: [current_bar, previous_bar],
        price_low: D.new("95"),
        price_low_set_bars_ago: 0,
        mean_vol: D.new("800"),
        mean_spread: D.new("4")
      }

      result = Vsa.Tag.set_two_bar_tag(context)

      assert List.first(result.bars).tag == nil
    end

    test "does not identify bottom reversal when current bar high is not higher than previous bar high" do
      # Current bar with high lower than previous bar's high
      current_bar = %Bar{
        direction: :up,
        closed: :very_high,
        high: D.new("99"),
        low: D.new("97"),
        close_price: D.new("99"),
        volume: D.new("1200"),
        spread: D.new("2"),
        time: ~U[2023-01-01 11:00:00Z],
        relative_volume: :high,
        relative_spread: :average,
        tag: nil,
        finished: true
      }

      previous_bar = %Bar{
        direction: :down,
        closed: :very_low,
        high: D.new("100"),
        low: D.new("95"),
        close_price: D.new("95"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        relative_volume: :average,
        relative_spread: :average,
        tag: nil,
        finished: true
      }

      context = %Context{
        bars: [current_bar, previous_bar],
        price_low: D.new("95"),
        price_low_set_bars_ago: 0,
        mean_vol: D.new("800"),
        mean_spread: D.new("4")
      }

      result = Vsa.Tag.set_two_bar_tag(context)

      assert List.first(result.bars).tag == nil
    end
  end

  describe "Confirmation of reversal indicators" do
    test "confirms top_reversal when next bar closes lower" do
      bar_to_confirm = %Bar{
        tag: :top_reversal,
        close_price: D.new("95"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        direction: :down,
        high: D.new("103"),
        low: D.new("95"),
        relative_volume: :high,
        relative_spread: :wide,
        closed: :very_low,
        opened: :high,
        finished: true
      }

      # Lower than current bar
      next_bar = %Bar{
        tag: :top_reversal,
        close_price: D.new("90"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        direction: :down,
        high: D.new("103"),
        low: D.new("95"),
        relative_volume: :high,
        relative_spread: :wide,
        closed: :very_low,
        opened: :high,
        finished: true
      }

      result = Vsa.Tag.confirm(bar_to_confirm, next_bar)

      assert result.tag == :top_reversal
    end

    test "marks top_reversal as unconfirmed when next bar closes higher" do
      bar_to_confirm = %Bar{
        tag: :top_reversal,
        close_price: D.new("95"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        direction: :down,
        high: D.new("103"),
        low: D.new("95"),
        relative_volume: :high,
        relative_spread: :wide,
        closed: :very_low,
        opened: :high,
        finished: true
      }

      # Higher than current bar
      next_bar = %Bar{bar_to_confirm | close_price: D.new("100")}

      result = Vsa.Tag.confirm(bar_to_confirm, next_bar)

      assert result.tag == nil
    end

    test "confirms bottom_reversal when next bar closes higher" do
      bar_to_confirm = %Bar{
        tag: :bottom_reversal,
        close_price: D.new("105"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        direction: :up,
        high: D.new("105"),
        low: D.new("97"),
        relative_volume: :high,
        relative_spread: :wide,
        closed: :very_high,
        opened: :low,
        finished: true
      }

      # Higher than current bar
      next_bar = %Bar{
        tag: :bottom_reversal,
        close_price: D.new("110"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        direction: :up,
        high: D.new("105"),
        low: D.new("97"),
        relative_volume: :high,
        relative_spread: :wide,
        closed: :very_high,
        opened: :low,
        finished: true
      }

      result = Vsa.Tag.confirm(bar_to_confirm, next_bar)

      assert result.tag == :bottom_reversal
    end

    test "marks bottom_reversal as unconfirmed when next bar closes lower" do
      bar_to_confirm = %Bar{
        tag: :bottom_reversal,
        close_price: D.new("105"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        direction: :up,
        high: D.new("105"),
        low: D.new("97"),
        relative_volume: :high,
        relative_spread: :wide,
        closed: :very_high,
        opened: :low,
        finished: true
      }

      # Lower than current bar
      next_bar = %Bar{
        tag: :bottom_reversal,
        close_price: D.new("100"),
        volume: D.new("1000"),
        spread: D.new("5"),
        time: ~U[2023-01-01 10:00:00Z],
        direction: :up,
        high: D.new("105"),
        low: D.new("97"),
        relative_volume: :high,
        relative_spread: :wide,
        closed: :very_high,
        opened: :low,
        finished: true
      }

      result = Vsa.Tag.confirm(bar_to_confirm, next_bar)

      assert result.tag == nil
    end
  end
end
