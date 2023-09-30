Mix.install([
  {:req, "~> 0.3.10"},
  {:jason, "~> 1.4"},
  {:decimal, "~> 2.1"}
])

url = "https://www.okx.com/api/v5/market/history-candles"
instrument = "?instId=BTC-USDT"

{:ok, response} = Req.request(url: url <> instrument)

attributes = [:ts, :open, :high, :low, :close, :vol, :volCcy, :confirm]

data =
  response.body["data"]
  |> Enum.map(
    &(Enum.zip_with(
        [attributes, &1],
        fn
          [:ts, y] ->
            {:ts, String.to_integer(y)}

          [x, y] ->
            {x, Decimal.new(y)}
        end
      )
      |> Enum.into(%{}))
  )

latest_ts = response.body["data"] |> Enum.at(-1) |> Enum.at(0)

{:ok, response2} = Req.request(url: url <> instrument <> "&after=#{latest_ts}")

data2 =
  response2.body["data"]
  |> Enum.map(
    &(Enum.zip_with(
        [attributes, &1],
        fn
          [:ts, y] ->
            {:ts, String.to_integer(y)}

          [x, y] ->
            {x, Decimal.new(y)}
        end
      )
      |> Enum.into(%{}))
  )

combined = (data ++ data2) |> Enum.reverse()
File.write!("BTC_test_data.ex", :erlang.term_to_binary(combined))

# data = File.read!("BTC_test_data.ex") |> :erlang.binary_to_term()
# results = data |> Enum.reverse() |> VSA.analyze()
# results.bars |> Enum.map(&to_string/1) |> Enum.join("") |> then(& File.write("results.txt", &1))
