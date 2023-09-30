defmodule VSATestJune28Test do
  use ExUnit.Case, async: true

  doctest VSA

  @raw_data File.read!("BTC_test_data.ex") |> :erlang.binary_to_term()

  test "raw data works" do
    assert Enum.count(@raw_data) === 200
  end

  test "analyze/1 doesn't crashes" do
    assert %VSA.Context{} = VSA.analyze(@raw_data)
  end

  test "analyze/1 produce 100 bars" do
    %VSA.Context{bars: bars} = VSA.analyze(@raw_data)

    assert Enum.count(bars) === 100
  end
end
