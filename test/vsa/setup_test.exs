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
        low: bar.low,
        close_price: bar.close_price,
        inception_time: bar.time
      }
    end

    test "with professional_selling climactic action - creates a new setup" do
      %VSA.Context{bars: [bar | _]} = context = context_with_climactic_last_bar(tag: :professional_selling)

      setup = VSA.Setup.capture(context)

      assert setup == %VSA.Setup{
        principle: :professional_selling,
        volume: bar.volume,
        high: bar.high,
        low: bar.low,
        close_price: bar.close_price,
        inception_time: bar.time
      }
    end

    test "captured climactic setup carries the bar's close_price verbatim" do
      context = context_with_climactic_last_bar(tag: :professional_buying, close_price: Decimal.new("64111"))

      assert %VSA.Setup{close_price: %Decimal{} = close} = VSA.Setup.capture(context)
      assert Decimal.equal?(close, Decimal.new("64111"))
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
        tag: :no_demand,
        status: :unconfirmed,
        close_price: Decimal.new("66005"),
        volume: Decimal.new("250")
      })

      context = context_with_setup(setup: setup, bars: [unconfirmed_no_demand_bar])

      assert %VSA.Setup{
        principle: :professional_buying,
        confirmations: [%{tag: :no_demand, status: :unconfirmed}]
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
        tag: :test,
        status: :unconfirmed,
        close_price: Decimal.new("61999"),
        volume: Decimal.new("250")
      })

      context = context_with_setup(setup: setup, bars: [unconfirmed_test_bar])

      assert %VSA.Setup{
        principle: :professional_selling,
        confirmations: [%{tag: :test, status: :unconfirmed}]
      } = VSA.Setup.capture(context)
    end

    test "with selling_climax - starts a strength setup, like professional_buying" do
      %VSA.Context{bars: [bar | _]} = context = context_with_climactic_last_bar(tag: :selling_climax)

      assert VSA.Setup.capture(context) == %VSA.Setup{
        principle: :selling_climax,
        volume: bar.volume,
        high: bar.high,
        low: bar.low,
        close_price: bar.close_price,
        inception_time: bar.time
      }
    end

    test "with bag_holding - starts a strength setup" do
      context = context_with_climactic_last_bar(tag: :bag_holding)

      assert %VSA.Setup{principle: :bag_holding} = VSA.Setup.capture(context)
    end

    test "with buying_climax - starts a weakness setup" do
      %VSA.Context{bars: [bar | _]} = context = context_with_climactic_last_bar(tag: :buying_climax)

      assert VSA.Setup.capture(context) == %VSA.Setup{
        principle: :buying_climax,
        volume: bar.volume,
        high: bar.high,
        low: bar.low,
        close_price: bar.close_price,
        inception_time: bar.time
      }
    end

    test "with end_of_rising_market - starts a weakness setup" do
      context = context_with_climactic_last_bar(tag: :end_of_rising_market)

      assert %VSA.Setup{principle: :end_of_rising_market} = VSA.Setup.capture(context)
    end

    test "strength setup + no_supply above the high - adds confirmation (penetration)" do
      setup = %VSA.Setup{
        principle: :selling_climax,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      no_supply_bar = bar(%{tag: :no_supply, close_price: Decimal.new("66005"), volume: Decimal.new("250")})
      context = context_with_setup(setup: setup, bars: [no_supply_bar])

      assert %VSA.Setup{confirmations: [%{tag: :no_supply}]} = VSA.Setup.capture(context)
    end

    test "strength setup + no_supply inside the area - does not confirm (penetration)" do
      setup = %VSA.Setup{
        principle: :selling_climax,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      no_supply_bar = bar(%{tag: :no_supply, close_price: Decimal.new("64005"), volume: Decimal.new("250")})
      context = context_with_setup(setup: setup, bars: [no_supply_bar])

      assert %VSA.Setup{confirmations: []} = VSA.Setup.capture(context)
    end

    test "strength setup + stopping_volume - confirms unconditionally" do
      setup = %VSA.Setup{
        principle: :professional_buying,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      bar = bar(%{tag: :stopping_volume, close_price: Decimal.new("63000"), volume: Decimal.new("250")})
      context = context_with_setup(setup: setup, bars: [bar])

      assert %VSA.Setup{confirmations: [%{tag: :stopping_volume}]} = VSA.Setup.capture(context)
    end

    test "weakness setup + no_demand_at_top below the low - adds confirmation (penetration)" do
      setup = %VSA.Setup{
        principle: :buying_climax,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      bar = bar(%{tag: :no_demand_at_top, close_price: Decimal.new("61999"), volume: Decimal.new("250")})
      context = context_with_setup(setup: setup, bars: [bar])

      assert %VSA.Setup{confirmations: [%{tag: :no_demand_at_top}]} = VSA.Setup.capture(context)
    end

    test "weakness setup + churning - confirms unconditionally" do
      setup = %VSA.Setup{
        principle: :professional_selling,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      bar = bar(%{tag: :churning, close_price: Decimal.new("64000"), volume: Decimal.new("250")})
      context = context_with_setup(setup: setup, bars: [bar])

      assert %VSA.Setup{confirmations: [%{tag: :churning}]} = VSA.Setup.capture(context)
    end

    test "polarity mismatch - a weakness confirmation against a strength setup is ignored" do
      setup = %VSA.Setup{
        principle: :selling_climax,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      bar = bar(%{tag: :churning, close_price: Decimal.new("64000"), volume: Decimal.new("250")})
      context = context_with_setup(setup: setup, bars: [bar])

      assert %VSA.Setup{confirmations: []} = VSA.Setup.capture(context)
    end

    test "regime flip - a buying_climax during a strength setup replaces it with a weakness setup" do
      strength_setup = %VSA.Setup{
        principle: :selling_climax,
        high: Decimal.new("66000"),
        low: Decimal.new("62000"),
        confirmations: []
      }

      buying_climax_bar = bar(%{tag: :buying_climax, close_price: Decimal.new("70000"), volume: Decimal.new("250")})
      context = context_with_setup(setup: strength_setup, bars: [buying_climax_bar])

      assert %VSA.Setup{principle: :buying_climax, confirmations: []} = VSA.Setup.capture(context)
    end
  end
end
