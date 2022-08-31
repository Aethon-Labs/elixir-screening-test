defmodule ElixirInterviewStarter.CalibrationSupervisor do
  @moduledoc """
  Starts Calibration Supervisor
  """
  use DynamicSupervisor
  alias ElixirInterviewStarter.CalibrationServer

  def start_link do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    Registry.start_link(keys: :unique, name: Registry.CalibrationSession)
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Start a Calibration process and add it to supervision
  def start_calibration_session(user_email) do
    child_spec = {CalibrationServer, user_email}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  # Terminate a Calibration process and remove it from supervision
  def stop_calibration_session(user_email) do
    case Registry.lookup(Registry.CalibrationSession, "user_email-" <> user_email) do
      [{pid, _} | _tail] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      _ -> :not_found
    end
  end

  # Nice utility method to check which processes are under supervision
  def children do
    DynamicSupervisor.which_children(__MODULE__)
  end

  # Nice utility method to check which processes are under supervision
  def count_children do
    DynamicSupervisor.count_children(__MODULE__)
  end
end
