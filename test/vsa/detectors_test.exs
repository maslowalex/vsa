defmodule VSA.DetectorsTest do
  use ExUnit.Case, async: true

  alias VSA.{Bar, Context, Level, Thresholds}
  alias Decimal, as: D

  defp bar(fields) do
    defaults = %{
      time: ~U[2024-01-01 00:00:00Z],
      close_price: D.new("100"),
      spread: D.new("10"),
      volume: D.new("1000"),
      high: D.new("105"),
      low: D.new("95"),
      direction: :down,
      relative_volume: :average,
      relative_spread: :average,
      closed: :middle,
      opened: :middle,
      finished: true
    }

    struct!(Bar, Map.merge(defaults, fields))
  end

  defp ctx(fields \\ %{}) do
    struct!(Context, Map.merge(%{thresholds: %Thresholds{}, bars: []}, fields))
  end

  defp tag(ctx, bar), do: Vsa.Tag.assign(ctx, bar).tag

  describe "selling_climax" do
    test "wide ultra-high down bar closing off the low in a down move" do
      bar = bar(%{direction: :down, relative_volume: :ultra_high, relative_spread: :wide, trend: :down})
      assert tag(ctx(), bar) == :selling_climax
    end

    test "does not fire outside a down move" do
      bar = bar(%{direction: :down, relative_volume: :ultra_high, relative_spread: :wide, trend: :up})
      refute tag(ctx(), bar) == :selling_climax
    end
  end

  describe "buying_climax" do
    test "wide ultra-high up bar closing off the high into fresh high ground" do
      bar = bar(%{direction: :up, relative_volume: :ultra_high, relative_spread: :wide, close_price: D.new("99")})
      assert tag(ctx(%{price_high: D.new("104")}), bar) == :buying_climax
    end

    test "does not fire without fresh high ground" do
      bar = bar(%{direction: :up, relative_volume: :ultra_high, relative_spread: :wide, close_price: D.new("99")})
      refute tag(ctx(%{price_high: D.new("999")}), bar) == :buying_climax
    end
  end

  describe "end_of_rising_market" do
    test "narrow high-volume up bar closing off the high into fresh ground" do
      bar = bar(%{direction: :up, relative_volume: :high, relative_spread: :narrow, close_price: D.new("99")})
      assert tag(ctx(%{price_high: D.new("104")}), bar) == :end_of_rising_market
    end
  end

  describe "stopping_volume" do
    test "high-volume down bar with a narrowing spread closing off the low in a down move" do
      prev = bar(%{spread: D.new("20")})

      bar =
        bar(%{
          direction: :down,
          relative_volume: :high,
          relative_spread: :narrow,
          closed: :middle,
          spread: D.new("10"),
          trend: :down
        })

      assert tag(ctx(%{bars: [prev]}), bar) == :stopping_volume
    end

    test "does not fire when the spread widens" do
      prev = bar(%{spread: D.new("5")})

      bar =
        bar(%{direction: :down, relative_volume: :high, relative_spread: :narrow, closed: :middle, spread: D.new("10"), trend: :down})

      refute tag(ctx(%{bars: [prev]}), bar) == :stopping_volume
    end
  end

  describe "churning" do
    test "ultra-high volume narrow bar after another high-volume bar" do
      prev = bar(%{relative_volume: :high})
      bar = bar(%{direction: :level, relative_volume: :ultra_high, relative_spread: :narrow})
      assert tag(ctx(%{bars: [prev]}), bar) == :churning
    end
  end

  describe "no_result_from_effort" do
    test "wide down bar closing on the low after an effort to rise" do
      penult = bar(%{direction: :up, volume: D.new("100"), low: D.new("95"), close_price: D.new("99")})
      prev = bar(%{direction: :up, volume: D.new("150"), low: D.new("96"), close_price: D.new("101")})

      bar =
        bar(%{
          direction: :down,
          relative_volume: :high,
          relative_spread: :wide,
          closed: :low,
          low: D.new("90"),
          close_price: D.new("91")
        })

      assert tag(ctx(%{bars: [prev, penult]}), bar) == :no_result_from_effort
    end
  end

  describe "no_supply vs test (background-gated)" do
    setup do
      prev = bar(%{volume: D.new("2000")})
      penult = bar(%{volume: D.new("2000")})

      bar =
        bar(%{direction: :down, relative_volume: :low, relative_spread: :narrow, volume: D.new("100")})

      %{bars: [prev, penult], bar: bar}
    end

    test "emits no_supply with strength in the background", %{bars: bars, bar: bar} do
      assert tag(ctx(%{bars: bars, background: :strength}), bar) == :no_supply
    end

    test "emits test with a neutral background", %{bars: bars, bar: bar} do
      assert tag(ctx(%{bars: bars, background: :neutral}), bar) == :test
    end
  end

  describe "bag_holding (two-bar)" do
    test "prior heavy-supply bar then a new-low bar closing mid/high" do
      prev = bar(%{relative_volume: :ultra_high, low: D.new("95")})

      bar =
        bar(%{
          direction: :down,
          low: D.new("90"),
          closed: :high,
          relative_spread: :average,
          relative_volume: :average,
          close_price: D.new("94")
        })

      assert tag(ctx(%{bars: [prev]}), bar) == :bag_holding
    end

    test "does not fire without a new low" do
      prev = bar(%{relative_volume: :ultra_high, low: D.new("95")})
      bar = bar(%{direction: :down, low: D.new("96"), closed: :high, relative_volume: :average})
      refute tag(ctx(%{bars: [prev]}), bar) == :bag_holding
    end
  end

  describe "absorption_volume (needs injected resistance)" do
    test "wide up bar closing on the high through an old resistance" do
      level = %Level{price: D.new("100"), kind: :resistance}
      prev = bar(%{close_price: D.new("99")})

      bar =
        bar(%{
          direction: :up,
          relative_volume: :high,
          relative_spread: :wide,
          closed: :high,
          close_price: D.new("101"),
          levels: [level]
        })

      assert tag(ctx(%{bars: [prev]}), bar) == :absorption_volume
    end

    test "does not fire without injected levels" do
      prev = bar(%{close_price: D.new("99")})

      bar =
        bar(%{direction: :up, relative_volume: :high, relative_spread: :wide, closed: :high, close_price: D.new("101")})

      refute tag(ctx(%{bars: [prev]}), bar) == :absorption_volume
    end
  end

  describe "wide_spread_down_through_support (needs injected support)" do
    test "wide down bar closing on the low through an old support" do
      level = %Level{price: D.new("100"), kind: :support}
      prev = bar(%{close_price: D.new("101")})

      bar =
        bar(%{
          direction: :down,
          relative_spread: :wide,
          closed: :low,
          close_price: D.new("99"),
          levels: [level]
        })

      assert tag(ctx(%{bars: [prev]}), bar) == :wide_spread_down_through_support
    end
  end

  describe "no_demand_at_top (needs injected resistance)" do
    setup do
      prev = bar(%{volume: D.new("2000")})
      penult = bar(%{volume: D.new("2000")})
      %{bars: [prev, penult]}
    end

    test "a no-demand up bar whose high sits at an old resistance", %{bars: bars} do
      level = %Level{price: D.new("105"), kind: :resistance}

      bar =
        bar(%{
          direction: :up,
          relative_volume: :low,
          relative_spread: :narrow,
          high: D.new("105"),
          volume: D.new("100"),
          levels: [level]
        })

      assert tag(ctx(%{bars: bars, mean_spread: D.new("10")}), bar) == :no_demand_at_top
    end

    test "falls back to plain no_demand away from resistance / without levels", %{bars: bars} do
      bar =
        bar(%{
          direction: :up,
          relative_volume: :low,
          relative_spread: :narrow,
          high: D.new("105"),
          volume: D.new("100")
        })

      assert tag(ctx(%{bars: bars, mean_spread: D.new("10")}), bar) == :no_demand
    end
  end
end
