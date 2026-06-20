defmodule Generator do
  def call(test_data_file \\ "BTC_test_data.ex", file_path_to_save \\ "results.txt") do
    File.read!(test_data_file)
    |> :erlang.binary_to_term()
    |> Enum.map(&normalize_raw_bar/1)
    |> VSA.analyze()
    |> tap(fn vsa -> write_results_file(vsa, file_path_to_save) end)
  end

  # Stored OKX candles use :ts/:vol; the analysis input contract uses :timestamp/:volume.
  defp normalize_raw_bar(raw) do
    raw
    |> Map.put_new(:timestamp, Map.get(raw, :ts))
    |> Map.put_new(:volume, Map.get(raw, :vol))
  end

  defp write_results_file(vsa, filename) do
    vsa
    |> Map.get(:bars)
    |> Enum.map(&to_string/1)
    |> Enum.join("\n")
    |> then(fn result -> File.write!(filename, result) end)
  end
end
