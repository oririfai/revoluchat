defmodule Revoluchat.Grpc.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Server.Interceptors.Logger
  intercept Revoluchat.Grpc.Interceptors.AuthServer
  run(Revoluchat.Grpc.Server)
end
