defmodule Revoluchat.Workers.FcmPushWorkerTest do
  use ExUnit.Case, async: true
  alias Revoluchat.Workers.FcmPushWorker

  describe "build_message_payload/2" do
    test "correctly builds FCM v1 payload for chat messages with WIB title, avatar and truncation" do
      device_token = "test_device_token"
      msg_map = %{
        "body" => "Hello, this is a test chat message!",
        "conversation_id" => "conv_123",
        "id" => "msg_456",
        "type" => "text",
        "inserted_at" => "2026-05-21T15:30:00Z", # UTC time. Shifting +7 hours = 22:30 WIB
        "user" => %{
          "name" => "Rifai",
          "avatar_url" => "https://example.com/avatar.jpg"
        }
      }

      payload = FcmPushWorker.build_message_payload(device_token, msg_map)

      assert payload["message"]["token"] == device_token
      assert payload["message"]["notification"]["title"] == "Rifai • 22:30 WIB"
      assert payload["message"]["notification"]["body"] == "Hello, this is a test chat message!"
      assert payload["message"]["data"]["conversation_id"] == "conv_123"
      assert payload["message"]["data"]["message_id"] == "msg_456"
      assert payload["message"]["data"]["type"] == "text"
      assert payload["message"]["data"]["action"] == "open_chat"
      assert payload["message"]["data"]["sender_avatar_url"] == "https://example.com/avatar.jpg"
    end

    test "masks body if message is encrypted (Privacy First)" do
      device_token = "test_device_token"
      msg_map = %{
        "body" => "Highly secret private key...",
        "conversation_id" => "conv_123",
        "id" => "msg_456",
        "type" => "text",
        "is_encrypted" => true,
        "inserted_at" => "2026-05-21T15:30:00Z",
        "user" => %{
          "name" => "Rifai",
          "avatar_url" => "https://example.com/avatar.jpg"
        }
      }

      payload = FcmPushWorker.build_message_payload(device_token, msg_map)

      assert payload["message"]["notification"]["body"] == "🔒 New Encrypted Message"
    end

    test "masks body if is_encrypted is a string 'true'" do
      device_token = "test_device_token"
      msg_map = %{
        "body" => "Highly secret private key...",
        "conversation_id" => "conv_123",
        "id" => "msg_456",
        "type" => "text",
        "is_encrypted" => "true",
        "inserted_at" => "2026-05-21T15:30:00Z",
        "user" => %{
          "name" => "Rifai",
          "avatar_url" => "https://example.com/avatar.jpg"
        }
      }

      payload = FcmPushWorker.build_message_payload(device_token, msg_map)

      assert payload["message"]["notification"]["body"] == "🔒 New Encrypted Message"
    end

    test "truncates long message bodies to 100 characters" do
      device_token = "test_device_token"
      long_body = String.duplicate("a", 150)
      msg_map = %{
        "body" => long_body,
        "conversation_id" => "conv_123",
        "id" => "msg_456",
        "type" => "text",
        "inserted_at" => "2026-05-21T15:30:00Z",
        "user" => %{
          "name" => "Rifai",
          "avatar_url" => "https://example.com/avatar.jpg"
        }
      }

      payload = FcmPushWorker.build_message_payload(device_token, msg_map)
      
      truncated_expected = String.slice(long_body, 0, 100) <> "..."
      assert payload["message"]["notification"]["body"] == truncated_expected
    end

    test "correctly builds FCM data-only payload for android devices (platform == fcm)" do
      device_token = "test_device_token"
      msg_map = %{
        "body" => "Hello, this is for Android!",
        "conversation_id" => "conv_123",
        "id" => "msg_456",
        "type" => "text",
        "inserted_at" => "2026-05-21T15:30:00Z",
        "user" => %{
          "name" => "Rifai",
          "avatar_url" => "https://example.com/avatar.jpg"
        }
      }

      payload = FcmPushWorker.build_message_payload(device_token, msg_map, nil, "fcm")

      assert payload["message"]["token"] == device_token
      refute Map.has_key?(payload["message"], "notification")
      
      data = payload["message"]["data"]
      assert data["conversation_id"] == "conv_123"
      assert data["message_id"] == "msg_456"
      assert data["type"] == "text"
      assert data["action"] == "open_chat"
      assert data["sender_avatar_url"] == "https://example.com/avatar.jpg"
      assert data["sender_name"] == "Rifai"
      assert data["title"] == "Rifai • 22:30 WIB"
      assert data["body"] == "Hello, this is for Android!"
    end

    test "correctly extracts conversation_name and sender_avatar_url from extra_args with both string and atom keys" do
      device_token = "test_device_token"
      msg_map = %{
        "body" => "Hello Group!",
        "conversation_id" => "group_123",
        "id" => "msg_456",
        "type" => "text",
        "inserted_at" => "2026-05-21T15:30:00Z",
        "user" => %{
          "name" => "Rifai",
          "avatar_url" => "https://example.com/avatar.jpg"
        }
      }

      # Test with string keys
      extra_args_string = %{
        "conversation_name" => "String Group Name",
        "sender_avatar_url" => "https://example.com/string_avatar.jpg"
      }
      payload_string = FcmPushWorker.build_message_payload(device_token, msg_map, "group_123", "fcm", "app_123", extra_args_string)
      assert payload_string["message"]["data"]["conversation_name"] == "String Group Name"
      assert payload_string["message"]["data"]["sender_avatar_url"] == "https://example.com/avatar.jpg"
      assert payload_string["message"]["data"]["conversation_avatar_url"] == "https://example.com/string_avatar.jpg"

      # Test with atom keys
      extra_args_atom = %{
        conversation_name: "Atom Group Name",
        sender_avatar_url: "https://example.com/atom_avatar.jpg"
      }
      payload_atom = FcmPushWorker.build_message_payload(device_token, msg_map, "group_123", "fcm", "app_123", extra_args_atom)
      assert payload_atom["message"]["data"]["conversation_name"] == "Atom Group Name"
      assert payload_atom["message"]["data"]["sender_avatar_url"] == "https://example.com/avatar.jpg"
      assert payload_atom["message"]["data"]["conversation_avatar_url"] == "https://example.com/atom_avatar.jpg"
    end

    test "sets conversation_avatar_url to empty string when group has no custom avatar url" do
      device_token = "test_device_token"
      msg_map = %{
        "body" => "Hello Group!",
        "conversation_id" => "group_123",
        "id" => "msg_456",
        "type" => "text",
        "inserted_at" => "2026-05-21T15:30:00Z",
        "user" => %{
          "name" => "Rifai",
          "avatar_url" => "https://example.com/avatar.jpg"
        }
      }

      extra_args = %{
        "conversation_name" => "Empty Avatar Group",
        "sender_avatar_url" => ""
      }
      payload = FcmPushWorker.build_message_payload(device_token, msg_map, "group_123", "fcm", "app_123", extra_args)
      assert payload["message"]["data"]["conversation_name"] == "Empty Avatar Group"
      assert payload["message"]["data"]["sender_avatar_url"] == "https://example.com/avatar.jpg"
      assert payload["message"]["data"]["conversation_avatar_url"] == ""
    end
  end

  describe "build_call_payload/2" do
    test "correctly builds FCM v1 payload for incoming call alerts" do
      device_token = "test_device_token"
      call_map = %{
        "call_id" => "call_789",
        "caller_id" => 42,
        "caller_name" => "John Doe",
        "caller_photo" => "https://example.com/photo.jpg",
        "phone_number" => "+628123456789",
        "type" => "video"
      }

      payload = FcmPushWorker.build_call_payload(device_token, call_map)

      assert payload["message"]["token"] == device_token
      assert payload["message"]["android"]["priority"] == "high"
      assert payload["message"]["notification"]["title"] == "Incoming Video Call"
      assert payload["message"]["notification"]["body"] == "John Doe is calling you..."
      
      data = payload["message"]["data"]
      assert data["call_id"] == "call_789"
      assert data["caller_id"] == "42"
      assert data["caller_name"] == "John Doe"
      assert data["caller_photo"] == "https://example.com/photo.jpg"
      assert data["phone_number"] == "+628123456789"
      assert data["type"] == "video"
      assert data["action"] == "incoming_call"
    end
  end
end
