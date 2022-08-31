defmodule ElixirInterviewStarter.App do
  use Application

  def start(_type, _args) do
    children = [
      {ElixirInterviewStarter.CalibrationSupervisor, []},
      {Registry, [keys: :unique, name: ElixirInterviewStarter.Registry]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
