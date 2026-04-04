defmodule RevoluchatWeb.DebugController do
  use RevoluchatWeb, :controller

  def upload(conn, params) do
    IO.inspect(params, label: "[DEBUG-UPLOAD] Received Params")
    
    case params["file"] do
      %Plug.Upload{filename: name, path: path} ->
        IO.puts("[DEBUG-UPLOAD] SUCCESS! Received file: #{name} at #{path}")
        json(conn, %{status: "ok", message: "File received locally"})
      _ ->
        IO.puts("[DEBUG-UPLOAD] FAILED! No file part found in params")
        json(conn, %{status: "error", message: "No file found"})
    end
  end
end
