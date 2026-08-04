defmodule Droodotfoo.SentryFilterTest do
  use ExUnit.Case, async: true

  alias Droodotfoo.SentryFilter

  defp event_for(exception) do
    Sentry.Event.transform_exception(exception, [])
  end

  describe "filter_event/1 with transport errors" do
    test "drops Bandit transport errors from clients that disconnect mid-request" do
      exception = %Bandit.TransportError{message: "Unrecoverable error: closed", error: :closed}

      assert SentryFilter.filter_event(event_for(exception)) == nil
    end

    test "drops Bandit transport errors regardless of the underlying reason" do
      for reason <- [:closed, :econnreset, :etimedout, :enotconn] do
        exception = %Bandit.TransportError{
          message: "Unrecoverable error: #{reason}",
          error: reason
        }

        assert SentryFilter.filter_event(event_for(exception)) == nil
      end
    end
  end

  describe "filter_event/1 with actionable errors" do
    test "keeps application exceptions" do
      event = event_for(%RuntimeError{message: "something broke"})

      assert SentryFilter.filter_event(event) == event
    end
  end

  describe "filter_event/1 with infrastructure errors" do
    test "drops database connection errors" do
      exception = %DBConnection.ConnectionError{message: "connection not available"}

      assert SentryFilter.filter_event(event_for(exception)) == nil
    end
  end
end
