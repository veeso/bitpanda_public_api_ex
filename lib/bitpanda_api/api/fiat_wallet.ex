defmodule BitpandaApi.Api.FiatWallet do
  @moduledoc """
  API request to collect user's fiat wallets
  """

  import Brex.Result.Base
  import Brex.Result.Helpers
  import Brex.Result.Mappers

  alias BitpandaApi.Api.Error
  alias BitpandaApi.Entity.FiatWallet
  alias BitpandaApi.Utils
  alias Decimal

  @doc """
  Get user's fiat wallets
  """
  @spec get(String.t()) :: {:ok, [FiatWallet.t()]} | {:error, Error.t()}
  def get(apikey) do
    "#{BitpandaApi.user_api_url()}/fiatwallets"
    |> HTTPoison.get([{"X-API-KEY", apikey}])
    |> map_error(&Error.http_error(&1))
    |> bind(&parse_response(Map.get(&1, :body), Map.get(&1, :status_code)))
  end

  @doc """
  Get user's fiat wallets; raise exception on error
  """
  @spec get!(String.t()) :: [FiatWallet.t()]
  def get!(apikey) do
    apikey
    |> get()
    |> extract!()
  end

  @spec parse_response(String.t(), integer()) :: {:ok, [FiatWallet.t()]} | {:error, Error.t()}
  defp parse_response(body, 200) do
    body
    |> Poison.decode(%{keys: :atoms})
    |> map_error(&Error.parse_error(inspect(&1)))
    |> bind(&json_to_wallets(&1))
  end

  defp parse_response(_, 401), do: error(Error.unauthorized())
  defp parse_response(_, _), do: error(Error.server_error())

  @spec json_to_wallets(%{data: [map()]}) ::
          {:ok, [FiatWallet.t()]} | {:error, Error.t()}
  defp json_to_wallets(%{data: data}), do: map_while_success(data, &data_to_wallet(&1))

  @spec data_to_wallet(%{
          type: String.t(),
          id: String.t(),
          attributes: %{
            fiat_id: String.t(),
            fiat_symbol: String.t(),
            balance: String.t(),
            name: String.t(),
            pending_transactions_count: integer()
          }
        }) ::
          {:ok, FiatWallet.t()} | {:error, Error.t()}
  defp data_to_wallet(%{
         type: "fiat_wallet",
         id: id,
         attributes: %{
           fiat_id: fiat_id,
           fiat_symbol: fiat_symbol,
           balance: balance,
           name: name,
           pending_transactions_count: pending_transactions_count
         }
       }) do
    ok(%FiatWallet{
      balance: Utils.decimal!(balance),
      fiat_id: fiat_id,
      id: id,
      name: name,
      pending_transactions_count: pending_transactions_count,
      symbol: fiat_symbol
    })
  catch
    error ->
      error(Error.parse_error(inspect(error)))
  end

  defp data_to_wallet(_), do: error(Error.parse_error("bad wallet attributes"))
end
