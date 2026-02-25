defmodule Revoluchat.Notifications do
  @moduledoc """
  Context untuk push notification management.
  """

  import Ecto.Query
  alias Revoluchat.Repo
  alias Revoluchat.Notifications.PushToken

  def register_push_token(app_id, user_id, platform, token) do
    # Upsert: jika token sudah ada, update user_id dan app_id-nya
    %PushToken{}
    |> PushToken.changeset(%{app_id: app_id, user_id: user_id, platform: platform, token: token})
    |> Repo.insert(
      on_conflict: [set: [app_id: app_id, user_id: user_id, updated_at: DateTime.utc_now()]],
      conflict_target: :token
    )
  end

  def get_push_tokens(app_id, user_id) do
    from(t in PushToken, where: t.app_id == ^app_id and t.user_id == ^user_id)
    |> Repo.all()
  end

  def delete_push_token(app_id, user_id, token) do
    from(t in PushToken,
      where: t.app_id == ^app_id and t.user_id == ^user_id and t.token == ^token
    )
    |> Repo.delete_all()

    :ok
  end
end
