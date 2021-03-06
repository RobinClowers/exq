defmodule Exq.Scheduler.Server do
  require Logger
  use GenServer
  alias Exq.Support.Config

  defmodule State do
    defstruct redis: nil, namespace: nil, queues: nil, scheduler_poll_timeout: nil
  end

  def start(opts \\ []) do
    GenServer.start(__MODULE__, [opts])
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [opts], [{:name, opts[:name]|| __MODULE__}])
  end

  def start_timeout(pid) do
    GenServer.cast(pid, {:start_timeout})
  end

##===========================================================
## gen server callbacks
##===========================================================

  def init([opts]) do
    namespace = Keyword.get(opts, :namespace, Config.get(:namespace, "exq"))
    queues = Keyword.get(opts, :queues)
    scheduler_poll_timeout = Keyword.get(opts, :scheduler_poll_timeout, Config.get(:scheduler_poll_timeout, 200))
    redis = opts[:redis]
    case Process.whereis(redis) do
      nil -> Exq.Redis.Supervisor.start_link(opts)
      _ -> :ok
    end
    state = %State{redis: redis, namespace: namespace,
      queues: queues, scheduler_poll_timeout: scheduler_poll_timeout}

    {:ok, state}
  end

  def handle_cast({:start_timeout}, state) do
    handle_info(:timeout, state)
  end

  def handle_cast(_request, state) do
    Logger.error("UNKNOWN CAST")
    {:noreply, state, 0}
  end

  def handle_call({:stop}, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_call(_request, _from, state) do
    Logger.error("UNKNOWN CALL")
    {:reply, :unknown, state, 0}
  end

  def handle_info(:timeout, state) do
    {updated_state, timeout} = dequeue(state)
    {:noreply, updated_state, timeout}
  end

##===========================================================
## Internal Functions
##===========================================================

  def dequeue(state) do
    Exq.Redis.JobQueue.scheduler_dequeue(state.redis, state.namespace, state.queues)
    {state, state.scheduler_poll_timeout}
  end

  def stop(_pid) do
  end

end
