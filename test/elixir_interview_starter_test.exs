defmodule ElixirInterviewStarterTest do
  use ExUnit.Case
  doctest ElixirInterviewStarter

  alias ElixirInterviewStarter.CalibrationSession
  alias ElixirInterviewStarter.CalibrationServer

  test "it can go through the whole flow happy path" do
    user_email = "test@email.com"

    assert {:ok, %CalibrationSession{current_step: "startPrecheck1"}} =
             ElixirInterviewStarter.start(user_email)

    pid = CalibrationServer.find_genserver_process(user_email)

    Process.send(pid, %{"precheck1" => true}, [:noconnect])

    assert {:ok, %CalibrationSession{current_step: "startPrecheck2"}} =
             ElixirInterviewStarter.start_precheck_2(user_email)

    Process.send(pid, %{"cartridgeStatus" => true}, [:noconnect])

    Process.send(pid, %{"submergedInWater" => true}, [:noconnect])

    assert {:ok,
            %CalibrationSession{
              current_step: "calibrate",
              cartridge_status: true,
              submerged_in_water: true
            }} = ElixirInterviewStarter.get_current_session(user_email)

    ElixirInterviewStarter.stop(user_email)
  end

  test "start/1 creates a new calibration session and starts precheck 1" do
  end

  test "start/1 returns an error if the provided user already has an ongoing calibration session" do
    ElixirInterviewStarter.start("test@email.com")

    assert ElixirInterviewStarter.start("test@email.com") ==
             {:error, "Calibration Session already in progress"}

    ElixirInterviewStarter.stop("test@email.com")
  end

  test "start_precheck_2/1 starts precheck 2" do
  end

  test "start_precheck_2/1 returns an error if the provided user does not have an ongoing calibration session" do
  end

  test "start_precheck_2/1 returns an error if the provided user's ongoing calibration session is not done with precheck 1" do
  end

  test "start_precheck_2/1 returns an error if the provided user's ongoing calibration session is already done with precheck 2" do
  end

  test "get_current_session/1 returns the provided user's ongoing calibration session" do
  end

  test "get_current_session/1 returns nil if the provided user has no ongoing calibrationo session" do
  end
end
