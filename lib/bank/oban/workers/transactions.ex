defmodule Bank.Oban.Workers.Transactions do
  @doc """
  Oban worker for transactions management
  """
  require Logger

  use Oban.Worker,
    max_attempts: 10,
    queue: :transactions,
    tags: ["transaction"]

  alias Bank.Transactions

  @one_hour_seconds 60 * 60

  @impl Oban.Worker
  def backoff(%Job{
        attempt: attempt,
        id: id,
        scheduled_at: scheduled_at,
        unsaved_error: unsaved_error
      }) do
    Logger.warning(
      "Oban backoff transaction #{id} attempt #{attempt} scheduled_at #{scheduled_at} with error: #{inspect(unsaved_error)}"
    )
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"transaction_id" => transaction_id} = args,
        id: id
      }) do
    IO.inspect(args, label: "args inspect=============")

    # TODO probar la transaction previa migracion, insertar una transaction en BD y

    {:ok, transaction} =
      transaction_id
      |> Transactions.get!()
      |> Transactions.update_status(:processing)

    case Transactions.complete(transaction) do
      {:ok} ->
        :ok

      {:error, failed_operation: operation, failed_value: value, changes_so_far: changes} ->
        # Ecto.Multi.failure/0
        failed_message =
          "while doing: #{inspect(operation)} with value: #{inspect(value)} and changes: #{inspect(changes)}"

        Logger.warning("Oban perform transaction #{id} failed #{failed_message}")
/
        {:snooze, 60}

      _ ->
        Logger.error("Oban perform transaction #{id} unknown error with args: #{inspect(args)}")

        {:error, "Unknown error with args: #{inspect(args)}"}
    end
  end

  @impl Oban.Worker
  def timeout(%_{args: %{"timeout" => timeout}}) when is_integer(timeout) and timeout > 0,
    do: :timer.seconds(timeout)

  def timeout(_job), do: :timer.seconds(@one_hour_seconds)
end
