defmodule CloudinaryTest do
  def run do
    cloud_name = "dypitcivk"
    api_key = "558947684814582"
    api_secret = "RmOQ3G45ewCgTSzu3-J5wntsl2k"
    
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    folder = "revoluchat/attachments"

    params = %{
      "folder" => folder,
      "overwrite" => "false",
      "timestamp" => timestamp,
      "unique_filename" => "true"
    }

    # Signature generation
    to_sign = params 
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join("&")
      |> Kernel.<>(api_secret)

    signature = :crypto.hash(:sha, to_sign) |> Base.encode16(case: :lower)
    
    IO.puts("--- DIAGNOSTIC v2 ---")
    IO.puts("String to Sign: #{to_sign}")
    IO.puts("Signature: #{signature}")
    
    url = "https://api.cloudinary.com/v1_1/#{cloud_name}/image/upload"
    
    # Multipart form data manual construction or simple POST with body
    # Using :httpc (Erlang standard)
    :inets.start()
    :ssl.start()
    
    boundary = "----CloudinaryBoundary#{timestamp}"
    
    body = [
      "--#{boundary}",
      "Content-Disposition: form-data; name=\"file\"",
      "",
      "https://cloudinary-res.cloudinary.com/image/upload/dpr_2.0,f_auto,q_auto/cloudinary_logo_for_white_bg.svg",
      "--#{boundary}",
      "Content-Disposition: form-data; name=\"api_key\"",
      "",
      api_key,
      "--#{boundary}",
      "Content-Disposition: form-data; name=\"timestamp\"",
      "",
      "#{timestamp}",
      "--#{boundary}",
      "Content-Disposition: form-data; name=\"folder\"",
      "",
      folder,
      "--#{boundary}",
      "Content-Disposition: form-data; name=\"signature\"",
      "",
      signature,
      "--#{boundary}",
      "Content-Disposition: form-data; name=\"unique_filename\"",
      "",
      "true",
      "--#{boundary}",
      "Content-Disposition: form-data; name=\"overwrite\"",
      "",
      "false",
      "--#{boundary}--",
      ""
    ] |> Enum.join("\r\n")

    headers = [
      {'Content-Type', String.to_charlist("multipart/form-data; boundary=#{boundary}")},
      {'User-Agent', 'ElixirDiagnostic'}
    ]
    
    IO.puts("Requesting: #{url}")
    
    case :httpc.request(:post, {String.to_charlist(url), headers, [], body}, [], []) do
      {:ok, {{_version, code, _reason}, _headers, body}} ->
        IO.puts("\nStatus: #{code}")
        IO.puts("Response:\n#{body}")
      {:error, reason} ->
        IO.puts("\nHTTP Error: #{inspect(reason)}")
    end
  end
end

CloudinaryTest.run()
