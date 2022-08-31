defmodule ElixirInterviewStarter do
  @moduledoc """
  See `README.md` for instructions on how to approach this technical challenge.
  """

  alias ElixirInterviewStarter.CalibrationSession
  alias ElixirInterviewStarter.CalibrationServer

  @spec start(user_email :: String.t()) :: {:ok, CalibrationSession.t()} | {:error, String.t()}
  @doc """
  Creates a new `CalibrationSession` for the provided user, starts a `GenServer` process
  for the session, and starts precheck 1.

  If the user already has an ongoing `CalibrationSession`, returns an error.
  """
  def start(user_email) do
    case CalibrationServer.start(user_email) do
      {:error, {:already_started, _current_pid}} ->
        {:error, "Calibration Session already in progress"}

      {:ok, _current_pid} ->
        CalibrationServer.get_current_session(user_email)
    end
  end

  # Terminate a Calibration process and remove it from supervision
  def stop(user_email), do: CalibrationServer.stop(user_email)

  @spec start_precheck_2(user_email :: String.t()) ::
          {:ok, CalibrationSession.t()} | {:error, String.t()}
  @doc """
  Starts the precheck 2 step of the ongoing `CalibrationSession` for the provided user.

  If the user has no ongoing `CalibrationSession`, their `CalibrationSession` is not done
  with precheck 1, or their calibration session has already completed precheck 2, returns
  an error.
  """
  def start_precheck_2(user_email) do
    CalibrationServer.start_precheck_2(user_email)
  end

  @spec get_current_session(user_email :: String.t()) :: {:ok, CalibrationSession.t() | nil}
  @doc """
  Retrieves the ongoing `CalibrationSession` for the provided user, if they have one
  """
  def get_current_session(user_email) do
    CalibrationServer.get_current_session(user_email)
  end
end
