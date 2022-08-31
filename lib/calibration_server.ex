defmodule ElixirInterviewStarter.CalibrationServer do
  use GenServer, restart: :temporary

  alias ElixirInterviewStarter.CalibrationSession
  alias ElixirInterviewStarter.DeviceMessages

  # Public API
  def start_link(user_email) do
    case GenServer.start_link(__MODULE__, %CalibrationSession{user_email: user_email},
           name: unique_process_name(user_email)
         ) do
      {:error, {:already_started, _current_pid}} ->
        {:error, "Calibration Session already in progress"}

      {:ok, _current_pid} ->
        {:ok, %CalibrationSession{user_email: user_email}}
    end
  end

  defp unique_process_name(user_email),
    do: {:via, Registry, {Registry.Calibration, "user_email-" <> user_email}}

  defp find_genserver_process(user_email), do: GenServer.whereis(unique_process_name(user_email))

  def start_precheck_1(user_email) do
    case find_genserver_process(user_email) do
      nil -> {:error, "No Calibration Session in progress"}
      pid -> GenServer.call(pid, :start_precheck_1, 30_000)
    end
  end

  def start_precheck_2(user_email) do
    case find_genserver_process(user_email) do
      nil -> {:error, "No Calibration Session in progress"}
      pid -> GenServer.call(pid, :start_precheck_2, 30_000)
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
    {:reply, {:ok, calibration_session}, calibration_session}
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
    calibration_session = %{calibration_session | current_step: "precheck1"}

    if precheck1 do
      {:reply, {:ok, calibration_session}, calibration_session}
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

    if cartridge_status do
      {:reply, {:ok, calibration_session}, calibration_session}
    else
      {:stop, :normal, %{calibration_session | failed_at: "cartridgeStatus"}}
    end
  end

  @impl true
  def handle_info(
        %{"submergedInWater" => submerged_in_water},
        %CalibrationSession{current_step: "startPrecheck2"} = calibration_session
      ) do
    calibration_session = %{calibration_session | submerged_in_water: submerged_in_water}

    if submerged_in_water do
      {:reply, {:ok, calibration_session}, calibration_session}
    else
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
      {:reply, {:ok, calibration_session}, calibration_session}
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
        %CalibrationSession{user_email: user_email, current_step: "precheck1"} =
          calibration_session
      ) do
    Process.send_after(self(), :precheck2_timeout, 30_000)
    DeviceMessages.send(user_email, "startPrecheck2")
    calibration_session = %{calibration_session | current_step: "startPrecheck2"}
    {:reply, {:ok, calibration_session}, calibration_session}
  end

  @impl true
  def handle_call(
        :calibrate,
        _from,
        %CalibrationSession{
          user_email: user_email,
          current_step: "startPrecheck2",
          cartridge_status: true,
          submerged_in_water: true
        } = calibration_session
      ) do
    Process.send_after(self(), :calibrate_timeout, 100_000)
    DeviceMessages.send(user_email, "calibrate")
    calibration_session = %{calibration_session | current_step: "calibrate"}
    {:reply, {:ok, calibration_session}, calibration_session}
  end

  @impl true
  def handle_call(:calibrate, _from, calibration_session) do
    {:stop, :normal, %{calibration_session | failed_at: "startPrecheck2"}}
  end

  @impl true
  def handle_call(:get_current_session, _from, calibration_session) do
    {:reply, {:ok, calibration_session}, calibration_session}
  end
end
