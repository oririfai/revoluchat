defmodule Revoluchat.Calls.Adapters.Postgres do
  @moduledoc """
  Postgres implementation of the Calls Adapter.
  """
  @behaviour Revoluchat.Calls.Adapter

  import Ecto.Query, warn: false
  require Logger
  alias Revoluchat.Repo
  alias Revoluchat.Calls.{Call, CallHistory}
  alias Revoluchat.Accounts

  def get_call(app_id, id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get_by(Call, [id: uuid, app_id: app_id])
      _ -> nil
    end
  end

  def is_participant?(app_id, call_id, user_id) do
    case get_call(app_id, call_id) do
      nil -> false
      call ->
        to_string(call.caller_id) == to_string(user_id) ||
        to_string(call.receiver_id) == to_string(user_id)
    end
  end

  def create_call(attrs), do: %Call{} |> Call.changeset(attrs) |> Repo.insert()

  def update_call(%Call{} = call, attrs), do: call |> Call.changeset(attrs) |> Repo.update()

  def initiate_call(_app_id, _conversation_id, _caller_id, _receiver_id, _type, _group_id \\ nil) do
    {:error, :not_supported_in_normal_tier}
  end

  defp do_initiate_call(app_id, conversation_id, caller_id, receiver_id, type) do
    attrs = %{
      app_id: app_id, conversation_id: conversation_id, caller_id: caller_id,
      receiver_id: receiver_id, type: type, status: "dialing", started_at: DateTime.utc_now()
    }

    with {:ok, call} <- create_call(attrs) do
      caller = Accounts.get_registered_user(app_id, caller_id)
      caller_identity = %{
        name: (caller && caller.name) || "Unknown",
        photo: (caller && caller.avatar_url),
        phone: (caller && caller.phone)
      }
      {:ok, call, caller_identity}
    end
  end

  def set_ringing(app_id, call_id) do
    case get_call(app_id, call_id) do
      nil -> {:error, :not_found}
      call -> update_call(call, %{status: "ringing"})
    end
  end

  def accept_call(app_id, call_id) do
    case get_call(app_id, call_id) do
      nil -> {:error, :not_found}
      call ->
        if call.status == "connected" do
           {:ok, call}
        else
          if call.status in ["dialing", "ringing"] do
            update_call(call, %{status: "connected", started_at: DateTime.utc_now()})
          else
            {:error, :invalid_status}
          end
        end
    end
  end

  def reject_call(app_id, call_id) do
    case get_call(app_id, call_id) do
      nil -> {:error, :not_found}
      call ->
        Repo.transaction(fn ->
          case update_call(call, %{status: "rejected", ended_at: DateTime.utc_now()}) do
            {:ok, updated_call} ->
              record_history(updated_call)
              updated_call
            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        end)
        |> case do
          {:ok, updated_call} -> {:ok, updated_call}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  def complete_call(app_id, call_id) do
    case get_call(app_id, call_id) do
      nil -> {:error, :not_found}
      call ->
        ended_at = DateTime.utc_now()
        new_status = if call.status == "connected", do: "completed", else: "missed"
        duration = if call.status == "connected" and call.started_at, do: DateTime.diff(ended_at, call.started_at), else: 0
        
        Repo.transaction(fn ->
          case update_call(call, %{status: new_status, ended_at: ended_at, duration_seconds: duration}) do
            {:ok, updated_call} ->
              record_history(updated_call)
              updated_call
            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        end)
        |> case do
          {:ok, updated_call} -> {:ok, updated_call}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  def cancel_call(app_id, call_id) do
    case get_call(app_id, call_id) do
      nil -> {:error, :not_found}
      call ->
        Repo.transaction(fn ->
          case update_call(call, %{status: "canceled", ended_at: DateTime.utc_now()}) do
            {:ok, updated_call} ->
              record_history(updated_call)
              updated_call
            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        end)
        |> case do
          {:ok, updated_call} -> {:ok, updated_call}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  def list_call_history(app_id, user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    other_party_id = Keyword.get(opts, :other_party_id)

    query = from(ch in CallHistory, where: ch.app_id == ^app_id and ch.user_id == ^user_id, order_by: [desc: ch.inserted_at], limit: ^limit)
    query = if other_party_id, do: from(ch in query, where: ch.other_party_id == ^other_party_id), else: query

    history_records = Repo.all(query)
    other_party_ids = Enum.map(history_records, & &1.other_party_id) |> Enum.uniq()
    users_data = Accounts.list_registered_users_by_ids(app_id, other_party_ids)
    users_map = Map.new(users_data, fn u -> {u.id, u} end)

    Enum.map(history_records, fn rec ->
      other = Map.get(users_map, rec.other_party_id)
      Map.merge(rec, %{
        other_party_name: (other && other.name) || "Unknown",
        other_party_avatar: (other && other.avatar_url),
        other_party_phone: (other && other.phone)
      })
    end)
  end

  def delete_call_history(app_id, user_id, ids) do
    valid_ids = ids |> Enum.map(fn id -> case Ecto.UUID.cast(id) do {:ok, uuid} -> uuid; _ -> nil end end) |> Enum.reject(&is_nil/1)
    if Enum.empty?(valid_ids) do
      {0, nil}
    else
      query = from(ch in CallHistory, where: ch.app_id == ^app_id and ch.user_id == ^user_id and ch.id in ^valid_ids)
      Repo.delete_all(query)
    end
  end

  defp record_history(%Call{} = call) do
    common = %{
      app_id: call.app_id,
      type: call.type,
      status: call.status,
      duration_seconds: call.duration_seconds || 0,
      started_at: call.started_at,
      conversation_id: call.conversation_id
    }

    with {:ok, _} <- %CallHistory{} |> CallHistory.changeset(Map.merge(common, %{user_id: call.caller_id, other_party_id: call.receiver_id, direction: "outgoing"})) |> Repo.insert(),
         {:ok, _} <- %CallHistory{} |> CallHistory.changeset(Map.merge(common, %{user_id: call.receiver_id, other_party_id: call.caller_id, direction: "incoming"})) |> Repo.insert() do
      :ok
    else
      {:error, changeset} -> Repo.rollback(changeset)
    end
  end
end
