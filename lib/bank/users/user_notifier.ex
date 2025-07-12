defmodule Bank.Users.UserNotifier do
  @moduledoc """
  Templates and emails send to the user.

  Generated with Phoenix.
  """
  import Swoosh.Email

  alias Bank.Mailer

  @type t :: {:ok | :error, term()}

  @doc """
  Deliver instructions to confirm account.
  """
  @spec deliver_confirmation_instructions(Ecto.Schema.t(), binary()) :: t()
  def deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  @spec deliver_reset_password_instructions(Ecto.Schema.t(), binary()) :: t()
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", """

    ==============================

    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  @spec deliver_update_email_instructions(Ecto.Schema.t(), binary()) :: t()
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  # Delivers the email using the application mailer.
  @spec deliver(binary(), binary(), binary()) :: t()
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Bank", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
