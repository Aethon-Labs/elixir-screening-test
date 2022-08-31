defmodule ElixirInterviewStarter.CalibrationSession do
  @moduledoc """
  A struct representing an ongoing calibration session, used to identify who the session
  belongs to, what step the session is on, and any other information relevant to working
  with the session.
  """

  @type t() :: %__MODULE__{}
  defstruct user_email: nil,
            current_step: nil,
            failed_at: nil,
            timeout_at: nil,
            cartridge_status: nil,
            submerged_in_water: nil,
            precheck1_timeout: 30_000,
            precheck2_timeout: 30_000,
            calibrate_timeout: 100_000
end
