defmodule VSA.ThresholdsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Decimal, as: D
  alias VSA.Thresholds

  describe "new/0" do
    test "creates struct with default values" do
      assert {:ok, thresholds} = Thresholds.new()

      assert D.eq?(thresholds.position_high_threshold, D.new("0.7"))
      assert D.eq?(thresholds.position_low_threshold, D.new("0.3"))
      assert D.eq?(thresholds.ultra_high_volume_factor, D.new("2.0"))
      assert D.eq?(thresholds.high_volume_factor, D.new("1.5"))
      assert D.eq?(thresholds.low_volume_factor, D.new("0.5"))
      assert D.eq?(thresholds.very_low_volume_factor, D.new("0.25"))
      assert D.eq?(thresholds.wide_spread_factor, D.new("1.5"))
      assert D.eq?(thresholds.narrow_spread_factor, D.new("0.7"))
      assert thresholds.bars_to_extreme_reset == 200
    end
  end

  describe "new!/0" do
    test "creates struct with default values" do
      thresholds = Thresholds.new!()

      assert D.eq?(thresholds.position_high_threshold, D.new("0.7"))
      assert D.eq?(thresholds.position_low_threshold, D.new("0.3"))
    end
  end

  describe "new/1" do
    test "allows overriding individual thresholds" do
      {:ok, thresholds} = Thresholds.new(position_high_threshold: D.new("0.8"))

      assert D.eq?(thresholds.position_high_threshold, D.new("0.8"))
      # Other values remain default
      assert D.eq?(thresholds.position_low_threshold, D.new("0.3"))
    end

    test "accepts string values and converts to Decimal" do
      {:ok, thresholds} = Thresholds.new(position_high_threshold: "0.85")

      assert D.eq?(thresholds.position_high_threshold, D.new("0.85"))
    end

    test "accepts float values and converts to Decimal" do
      {:ok, thresholds} = Thresholds.new(position_high_threshold: 0.8)

      assert D.eq?(thresholds.position_high_threshold, D.from_float(0.8))
    end

    test "accepts integer values and converts to Decimal" do
      {:ok, thresholds} = Thresholds.new(bars_to_extreme_reset: 100)

      assert thresholds.bars_to_extreme_reset == 100
    end
  end

  describe "validation - position thresholds" do
    test "rejects position_low_threshold <= 0" do
      assert {:error, reasons} = Thresholds.new(position_low_threshold: D.new("0"))
      assert Enum.any?(reasons, &String.contains?(&1, "position_low_threshold"))
    end

    test "rejects position_low_threshold >= 1" do
      assert {:error, reasons} = Thresholds.new(position_low_threshold: D.new("1"))
      assert Enum.any?(reasons, &String.contains?(&1, "position_low_threshold"))
    end

    test "rejects position_high_threshold <= position_low_threshold" do
      assert {:error, reasons} =
               Thresholds.new(
                 position_low_threshold: D.new("0.5"),
                 position_high_threshold: D.new("0.4")
               )

      assert Enum.any?(reasons, &String.contains?(&1, "must be greater than position_low"))
    end

    test "rejects position_high_threshold >= 1" do
      assert {:error, reasons} = Thresholds.new(position_high_threshold: D.new("1"))
      assert Enum.any?(reasons, &String.contains?(&1, "position_high_threshold"))
    end
  end

  describe "validation - volume factors" do
    test "rejects very_low_volume_factor <= 0" do
      assert {:error, reasons} = Thresholds.new(very_low_volume_factor: D.new("0"))
      assert Enum.any?(reasons, &String.contains?(&1, "very_low_volume_factor"))
    end

    test "rejects low_volume_factor <= very_low_volume_factor" do
      assert {:error, reasons} =
               Thresholds.new(
                 very_low_volume_factor: D.new("0.5"),
                 low_volume_factor: D.new("0.4")
               )

      assert Enum.any?(reasons, &String.contains?(&1, "low_volume_factor"))
    end

    test "rejects low_volume_factor >= 1" do
      assert {:error, reasons} = Thresholds.new(low_volume_factor: D.new("1.0"))
      assert Enum.any?(reasons, &String.contains?(&1, "low_volume_factor"))
    end

    test "rejects high_volume_factor <= 1" do
      assert {:error, reasons} = Thresholds.new(high_volume_factor: D.new("1.0"))
      assert Enum.any?(reasons, &String.contains?(&1, "high_volume_factor"))
    end

    test "rejects ultra_high_volume_factor <= high_volume_factor" do
      assert {:error, reasons} =
               Thresholds.new(
                 high_volume_factor: D.new("2.0"),
                 ultra_high_volume_factor: D.new("1.8")
               )

      assert Enum.any?(reasons, &String.contains?(&1, "ultra_high_volume_factor"))
    end
  end

  describe "validation - spread factors" do
    test "rejects narrow_spread_factor <= 0" do
      assert {:error, reasons} = Thresholds.new(narrow_spread_factor: D.new("0"))
      assert Enum.any?(reasons, &String.contains?(&1, "narrow_spread_factor"))
    end

    test "rejects narrow_spread_factor >= 1" do
      assert {:error, reasons} = Thresholds.new(narrow_spread_factor: D.new("1.0"))
      assert Enum.any?(reasons, &String.contains?(&1, "narrow_spread_factor"))
    end

    test "rejects wide_spread_factor <= 1" do
      assert {:error, reasons} = Thresholds.new(wide_spread_factor: D.new("1.0"))
      assert Enum.any?(reasons, &String.contains?(&1, "wide_spread_factor"))
    end
  end

  describe "validation - bars_to_extreme_reset" do
    test "rejects non-positive bars_to_extreme_reset" do
      assert {:error, reasons} = Thresholds.new(bars_to_extreme_reset: 0)
      assert Enum.any?(reasons, &String.contains?(&1, "bars_to_extreme_reset"))
    end

    test "rejects non-integer bars_to_extreme_reset" do
      assert {:error, reasons} = Thresholds.new(bars_to_extreme_reset: 1.5)
      assert Enum.any?(reasons, &String.contains?(&1, "bars_to_extreme_reset"))
    end
  end

  describe "new!/1" do
    test "raises on invalid thresholds" do
      assert_raise ArgumentError, ~r/Invalid thresholds/, fn ->
        Thresholds.new!(position_high_threshold: D.new("0.2"))
      end
    end
  end

  # Property-based tests

  describe "property: valid thresholds always pass validation" do
    property "any valid threshold configuration passes validation" do
      check all thresholds <- valid_thresholds_generator() do
        assert :ok = Thresholds.validate(thresholds)
      end
    end
  end

  describe "property: classification determinism" do
    property "same thresholds always produce the same struct" do
      check all opts <- valid_threshold_opts_generator() do
        {:ok, t1} = Thresholds.new(opts)
        {:ok, t2} = Thresholds.new(opts)

        assert t1 == t2
      end
    end
  end

  describe "property: system stability with valid thresholds" do
    property "VSA.init succeeds with any valid threshold configuration" do
      check all thresholds <- valid_thresholds_generator() do
        # Ensure bars_to_extreme_reset <= max_bars
        max_bars = max(thresholds.bars_to_extreme_reset, 200)

        ctx = VSA.init(max_bars: max_bars, thresholds: thresholds)
        assert %VSA.Context{} = ctx
        assert ctx.thresholds == thresholds
      end
    end
  end

  # Generators

  defp valid_thresholds_generator do
    gen all position_low <- float_between(0.05, 0.45),
            position_gap <- float_between(0.1, 0.4),
            very_low_vol <- float_between(0.05, 0.3),
            vol_gap_1 <- float_between(0.05, 0.3),
            high_vol <- float_between(1.05, 2.5),
            vol_gap_2 <- float_between(0.1, 2.0),
            narrow_spread <- float_between(0.1, 0.9),
            wide_spread <- float_between(1.05, 3.0),
            bars_reset <- StreamData.integer(1..500) do
      position_high = min(position_low + position_gap, 0.95)
      low_vol = min(very_low_vol + vol_gap_1, 0.95)
      ultra_high_vol = high_vol + vol_gap_2

      %Thresholds{
        position_low_threshold: D.from_float(position_low),
        position_high_threshold: D.from_float(position_high),
        very_low_volume_factor: D.from_float(very_low_vol),
        low_volume_factor: D.from_float(low_vol),
        high_volume_factor: D.from_float(high_vol),
        ultra_high_volume_factor: D.from_float(ultra_high_vol),
        narrow_spread_factor: D.from_float(narrow_spread),
        wide_spread_factor: D.from_float(wide_spread),
        bars_to_extreme_reset: bars_reset
      }
    end
  end

  defp valid_threshold_opts_generator do
    gen all thresholds <- valid_thresholds_generator() do
      [
        position_low_threshold: thresholds.position_low_threshold,
        position_high_threshold: thresholds.position_high_threshold,
        very_low_volume_factor: thresholds.very_low_volume_factor,
        low_volume_factor: thresholds.low_volume_factor,
        high_volume_factor: thresholds.high_volume_factor,
        ultra_high_volume_factor: thresholds.ultra_high_volume_factor,
        narrow_spread_factor: thresholds.narrow_spread_factor,
        wide_spread_factor: thresholds.wide_spread_factor,
        bars_to_extreme_reset: thresholds.bars_to_extreme_reset
      ]
    end
  end

  defp float_between(min, max) do
    StreamData.float(min: min, max: max)
  end
end
