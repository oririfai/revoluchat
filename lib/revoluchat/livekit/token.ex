defmodule Revoluchat.LiveKit.Token do
  @moduledoc """
  Generates LiveKit Access Tokens (JWT) for joining rooms.
  """
  use Joken.Config, default_signer: nil

  # Configure Joken base claims (optional but good practice)
  @impl true
  def token_config do
    default_claims(skip: [:aud, :jti])
  end

  @doc """
  Generates a LiveKit access token.
  
  ## Arguments
  * `room` - The ID or name of the room to join (e.g., call.id)
  * `participant_id` - Unique identifier for the user (e.g., user.id)
  * `participant_name` - Display name for the user
  """
  def generate(room, participant_id, participant_name) do
    config = Application.get_env(:revoluchat, :livekit, [])
    api_key = Keyword.get(config, :api_key, System.get_env("LIVEKIT_API_KEY") || "devkey")
    api_secret = Keyword.get(config, :api_secret, System.get_env("LIVEKIT_API_SECRET") || "secret")

    # Define the custom claims required by LiveKit
    claims = %{
      "iss" => api_key,
      "sub" => to_string(participant_id),
      "name" => participant_name,
      "video" => %{
        "roomJoin" => true,
        "room" => to_string(room),
        "canPublish" => true,
        "canSubscribe" => true
      }
    }

    # Generate token using HS256 algorithm with the API secret
    signer = Joken.Signer.create("HS256", api_secret)

    case generate_and_sign(claims, signer) do
      {:ok, token, _claims} -> {:ok, token}
      error -> error
    end
  end
end
