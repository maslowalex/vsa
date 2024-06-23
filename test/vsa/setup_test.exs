defmodule VSA.SetupTest do
  use ExUnit.Case, async: true

  import VSA.Fixtures

  describe "capture/1" do
    test "with professional_buying climactic_action - creates a new setup" do
      %VSA.Context{bars: [bar | _]} = context = context_with_climactic_last_bar(tag: :professional_buying)

      setup = VSA.Setup.capture(context)

      assert setup == %VSA.Setup{
        principle: :professional_buying,
        volume: bar.volume,
        high: bar.high,
        low: bar.low
      }
    end

    test "with professional_selling climactic action - creates a new setup" do
      %VSA.Context{bars: [bar | _]} = context = context_with_climactic_last_bar(tag: :professional_selling)

      setup = VSA.Setup.capture(context)

      assert setup == %VSA.Setup{
        principle: :professional_selling,
        volume: bar.volume,
        high: bar.high,
        low: bar.low
      }
    end

    test "with professional_buying setup and test above the high - adds confirmation" do
      setup = %VSA.Setup{
        principle: :professional_buying,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      test_bar = bar(%{
        tag: :test,
        close_price: Decimal.new("66005"),
        volume: Decimal.new("250")
      })

      context = context_with_setup(setup: setup, bars: [test_bar])

      assert %VSA.Setup{
        principle: :professional_buying,
        confirmations: [%{tag: :test}]
      } = VSA.Setup.capture(context)
    end

    test "with professional_buying setup and test in between high and low of the climactic bar - doesn't add it to confirmations" do
      setup = %VSA.Setup{
        principle: :professional_buying,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      test_bar = bar(%{
        tag: :test,
        close_price: Decimal.new("64005"),
        volume: Decimal.new("250")
      })

      context = context_with_setup(setup: setup, bars: [test_bar])

      assert %VSA.Setup{confirmations: []} = VSA.Setup.capture(context)
    end

    test "with professional_buying and shakeout - adds it to confirmations - no matter the close price" do
      setup = %VSA.Setup{
        principle: :professional_buying,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      shakeout_bar = bar(%{
        tag: :shakeout,
        close_price: Decimal.new("64005"),
        volume: Decimal.new("500")
      })

      context = context_with_setup(setup: setup, bars: [shakeout_bar])

      assert %VSA.Setup{
        principle: :professional_buying,
        confirmations: [%{tag: :shakeout}]
      } = VSA.Setup.capture(context)
    end

    test "with professional_buying and unconfirmed no_demand above the high of setup - adds to confirmations" do
      setup = %VSA.Setup{
        principle: :professional_buying,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      unconfirmed_no_demand_bar = bar(%{
        tag: :unconfirmed_no_demand,
        close_price: Decimal.new("66005"),
        volume: Decimal.new("250")
      })

      context = context_with_setup(setup: setup, bars: [unconfirmed_no_demand_bar])

      assert %VSA.Setup{
        principle: :professional_buying,
        confirmations: [%{tag: :unconfirmed_no_demand}]
      } = VSA.Setup.capture(context)
    end

    test "with professional_selling and no_demand below the setup low - adds to confirmations" do
      setup = %VSA.Setup{
        principle: :professional_selling,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      no_demand_bar = bar(%{
        tag: :no_demand,
        close_price: Decimal.new("61999"),
        volume: Decimal.new("250")
      })

      context = context_with_setup(setup: setup, bars: [no_demand_bar])

      assert %VSA.Setup{
        principle: :professional_selling,
        confirmations: [%{tag: :no_demand}]
      } = VSA.Setup.capture(context)
    end

    test "with professional_selling and no_demand in area of setup - skip it" do
      setup = %VSA.Setup{
        principle: :professional_selling,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      no_demand_bar = bar(%{
        tag: :no_demand,
        close_price: Decimal.new("64005"),
        volume: Decimal.new("250")
      })

      context = context_with_setup(setup: setup, bars: [no_demand_bar])

      assert %VSA.Setup{confirmations: []} = VSA.Setup.capture(context)
    end

    test "with professional_selling and upthrust - adds to confirmations no matter the close_price" do
      setup = %VSA.Setup{
        principle: :professional_selling,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      upthrust_bar = bar(%{
        tag: :upthrust,
        close_price: Decimal.new("66005"),
        volume: Decimal.new("500")
      })

      context = context_with_setup(setup: setup, bars: [upthrust_bar])

      assert %VSA.Setup{
        principle: :professional_selling,
        confirmations: [%{tag: :upthrust}]
      } = VSA.Setup.capture(context)
    end

    test "with professional_selling and unconfirmed test below the setup low - adds to confirmations" do
      setup = %VSA.Setup{
        principle: :professional_selling,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      unconfirmed_test_bar = bar(%{
        tag: :unconfirmed_test,
        close_price: Decimal.new("61999"),
        volume: Decimal.new("250")
      })

      context = context_with_setup(setup: setup, bars: [unconfirmed_test_bar])

      assert %VSA.Setup{
        principle: :professional_selling,
        confirmations: [%{tag: :unconfirmed_test}]
      } = VSA.Setup.capture(context)
    end
  end
end
