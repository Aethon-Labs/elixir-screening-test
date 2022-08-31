defmodule ElixirInterviewStarter.CalibrationServer do
  use GenServer, restart: :temporary

  alias ElixirInterviewStarter.CalibrationSession
  alias ElixirInterviewStarter.DeviceMessages
  alias ElixirInterviewStarter.CalibrationSupervisor

  # Public API
  def start_link(user_email) do
    GenServer.start_link(__MODULE__, user_email, name: unique_process_name(user_email))
  end

  def start(user_email) do
    DynamicSupervisor.start_child(CalibrationSupervisor, {__MODULE__, user_email})
  end

  # Terminate a Calibration process and remove it from supervision
  def stop(user_email) do
    case find_genserver_process(user_email) do
      nil -> :not_found
      pid -> GenServer.stop(pid)
    end
  end

  defp unique_process_name(user_email),
    do: {:via, Registry, {ElixirInterviewStarter.Registry, "user_email-" <> user_email}}

  def find_genserver_process(user_email), do: GenServer.whereis(unique_process_name(user_email))

  def start_precheck_2(user_email) do
    case find_genserver_process(user_email) do
      nil -> {:error, "No Calibration Session in progress"}
      pid -> GenServer.call(pid, :start_precheck_2)
    end
  end

  def get_current_session(user_email) do
    case find_genserver_process(user_email) do
      nil -> {:ok, nil}
      pid -> GenServer.call(pid, :get_current_session)
    end
  end

  @impl true
  def init(user_email) do
    {:ok, %CalibrationSession{user_email: user_email, current_step: "init"},
     {:continue, :start_precheck_1}}
  end

  @impl true
  def handle_continue(
        :start_precheck_1,
        %CalibrationSession{user_email: user_email} = calibration_session
      ) do
    Process.send_after(self(), :precheck1_timeout, 30_000)
    DeviceMessages.send(user_email, "startPrecheck1")
    calibration_session = %{calibration_session | current_step: "startPrecheck1"}
    {:noreply, calibration_session}
  end

  @impl true
  def handle_info(
        :precheck1_timeout,
        %CalibrationSession{current_step: "startPrecheck1"} = calibration_session
      ) do
    {:stop, :normal, %{calibration_session | timeout_at: "startPrecheck1"}}
  end

  @impl true
  def handle_info(
        :precheck1_timeout,
        %CalibrationSession{current_step: "init"} = calibration_session
      ) do
    {:noreply, calibration_session}
  end

  @impl true
  def handle_info(%{"precheck1" => precheck1}, calibration_session) do
    if precheck1 do
      {:noreply, %{calibration_session | current_step: "precheck1Completed"}}
    else
      {:stop, :normal, %{calibration_session | failed_at: "precheck1"}}
    end
  end

  @impl true
  def handle_info(
        %{"cartridgeStatus" => cartridge_status},
        %CalibrationSession{current_step: "startPrecheck2"} = calibration_session
      ) do
    calibration_session = %{calibration_session | cartridge_status: cartridge_status}

    cond do
      calibration_session.cartridge_status and calibration_session.submerged_in_water ->
        GenServer.cast(self(), :calibrate)
        {:noreply, %{calibration_session | current_step: "precheck2completed"}}

      calibration_session.cartridge_status ->
        {:noreply, calibration_session}

      true ->
        {:stop, :normal, %{calibration_session | failed_at: "cartridgeStatus"}}
    end
  end

  @impl true
  def handle_info(
        %{"submergedInWater" => submerged_in_water},
        %CalibrationSession{current_step: "startPrecheck2"} = calibration_session
      ) do
    calibration_session = %{calibration_session | submerged_in_water: submerged_in_water}

    cond do
      calibration_session.cartridge_status and calibration_session.submerged_in_water ->
        GenServer.cast(self(), :calibrate)
        {:noreply, %{calibration_session | current_step: "precheck2completed"}}

      calibration_session.submerged_in_water ->
        {:noreply, calibration_session}

      true ->
        {:stop, :normal, %{calibration_session | failed_at: "submergedInWater"}}
    end
  end

  @impl true
  def handle_info(
        :precheck2_timeout,
        %CalibrationSession{current_step: "startPrecheck2"} = calibration_session
      ) do
    {:stop, :normal, %{calibration_session | timeout_at: "startPrecheck2"}}
  end

  @impl true
  def handle_info(%{"calibrate" => calibrate}, calibration_session) do
    calibration_session = %{calibration_session | current_step: "completed"}

    if calibrate do
      {:noreply, calibration_session}
    else
      {:stop, :normal, %{calibration_session | failed_at: "calibrate"}}
    end
  end

  @impl true
  def handle_info(
        :calibrate_timeout,
        %CalibrationSession{current_step: "startPrecheck2"} = calibration_session
      ) do
    {:stop, :normal, %{calibration_session | timeout_at: "calibrate"}}
  end

  @impl true
  def handle_call(
        :start_precheck_2,
        _from,
        %CalibrationSession{user_email: user_email, current_step: "precheck1Completed"} =
          calibration_session
      ) do
    Process.send_after(self(), :precheck2_timeout, 30_000)
    DeviceMessages.send(user_email, "startPrecheck2")
    calibration_session = %{calibration_session | current_step: "startPrecheck2"}
    {:reply, {:ok, calibration_session}, calibration_session}
  end

  @impl true
  def handle_call(
        :start_precheck_2,
        _from,
        %CalibrationSession{current_step: current_step} = calibration_session
      ) do
    cond do
      current_step in ["precheck2completed", "calibrate", "completed"] ->
        {:reply, {:error, "precheck2 already completed"}, calibration_session}

      current_step in ["init", "startPrecheck1"] ->
        {:reply, {:error, "precheck1 not completed"}, calibration_session}

      true ->
        {:reply, {:error, "unknown error"}, calibration_session}
    end
  end

  @impl true
  def handle_call(:calibrate, _from, calibration_session) do
    {:stop, :normal, %{calibration_session | failed_at: "startPrecheck2"}}
  end

  @impl true
  def handle_call(:get_current_session, _from, calibration_session) do
    {:reply, {:ok, calibration_session}, calibration_session}
  end

  @impl true
  def handle_cast(
        :calibrate,
        %CalibrationSession{
          user_email: user_email,
          current_step: "precheck2completed",
          cartridge_status: true,
          submerged_in_water: true
        } = calibration_session
      ) do
    Process.send_after(self(), :calibrate_timeout, 100_000)
    DeviceMessages.send(user_email, "calibrate")
    calibration_session = %{calibration_session | current_step: "calibrate"}
    {:noreply, calibration_session}
  end
end
