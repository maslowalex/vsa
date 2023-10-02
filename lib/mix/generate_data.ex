defmodule Mix.Tasks.GenerateData do
  use Mix.Task

  @shortdoc "Generate a test data from OKex API"
  @requirements ["app.start"]

  @endpoint "https://www.okx.com/api/v5/market/history-candles"
  @attributes [:ts, :open, :high, :low, :close, :vol, :volCcy, :confirm]

  @impl Mix.Task
  def run(args) do
    [instrument] = args

    Mix.shell().info("Will generate test data for #{instrument}, 1 minute TF.")

    directory = make_current_date_directory!()
    data = fetch_data!(instrument)
    filename = Path.join([directory, "#{instrument}-#{current_timestamp()}.ex"])

    File.write!(filename, :erlang.term_to_binary(data))

    Mix.shell().info("Writed a file: #{filename}")
  end

  defp fetch_data!(instrument) do
    response = Req.get!(@endpoint <> "?instId=#{instrument}")

    response_body_data = Map.fetch!(response.body, "data")

    data = generate_data(response_body_data)

    latest_ts = response_body_data |> Enum.at(-1) |> Enum.at(0)

    Mix.shell().info("First chunk latest timestamp: #{human_readable_ts(latest_ts)}")

    second_chunk = Req.get!(@endpoint <> "?instId=#{instrument}" <> "&after=#{latest_ts}")

    second_chunk_data = Map.fetch!(second_chunk.body, "data")
    second_chunk_latest_ts = second_chunk_data |> Enum.at(-1) |> Enum.at(0)

    Mix.shell().info("Second chunk latest timestamp: #{human_readable_ts(second_chunk_latest_ts)}")

    data_2 = generate_data(second_chunk_data)

    (data ++ data_2) |> Enum.reverse()
  end

  defp generate_data(response_data) do
    response_data
    |> Enum.map(
      &(Enum.zip_with(
          [@attributes, &1],
          fn
            [:ts, y] ->
              {:ts, String.to_integer(y)}

            [x, y] ->
              {x, Decimal.new(y)}
          end
        )
        |> Enum.into(%{}))
    )
  end

  defp human_readable_ts(ts) do
    ts
    |> String.to_integer()
    |> DateTime.from_unix!(:millisecond)
  end

  defp current_timestamp do
    Time.utc_now()
    |> to_string()
    |> String.split(".")
    |> List.first()
  end

  defp make_current_date_directory! do
    current_date = Date.utc_today()
    current_date_directory = Path.join(["test", "data", to_string(current_date)])
    :ok = File.mkdir_p!(current_date_directory)

    current_date_directory
  end
end
