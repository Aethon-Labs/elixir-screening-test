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

  It accepts extra parameters as keyword list to change timeouts (ms):
   - precheck1_timeout (defaults to 30_000)
   - precheck2_timeout (defaults to 30_000)
   - calibrate_timeout (defaults to 100_000)
  """

  def start(user_email, opts \\ [])

  def start(user_email, opts) do
    calibration_session = %CalibrationSession{user_email: user_email}

    precheck1_timeout =
      Keyword.get(opts, :precheck1_timeout, calibration_session.precheck1_timeout)

    precheck2_timeout =
      Keyword.get(opts, :precheck2_timeout, calibration_session.precheck2_timeout)

    calibrate_timeout =
      Keyword.get(opts, :calibrate_timeout, calibration_session.calibrate_timeout)

    calibration_session = %{calibration_session | precheck1_timeout: precheck1_timeout}
    calibration_session = %{calibration_session | precheck2_timeout: precheck2_timeout}
    calibration_session = %{calibration_session | calibrate_timeout: calibrate_timeout}

    case CalibrationServer.start(calibration_session) do
      {:error, {:already_started, _current_pid}} ->
        {:error, "Calibration Session already in progress"}

      {:ok, _current_pid} ->
        CalibrationServer.get_current_session(user_email)
    end
  end

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
