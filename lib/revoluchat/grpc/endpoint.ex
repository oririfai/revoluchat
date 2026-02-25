defmodule Revoluchat.Grpc.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Server.Interceptors.Logger
  run(Revoluchat.Grpc.Server)
end
