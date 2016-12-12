defmodule Ueberauth.Strategy.Discord do
	@moduledoc """
	Provides an Ueberauth strategy for authenticating with Discord.
	"""

	use Ueberauth.Strategy, uid_field: :login,
													default_scope: "identify email",
													oauth2_module: Ueberauth.Strategy.Discord.OAuth
 
	alias Ueberauth.Auth.Info
	alias Ueberauth.Auth.Credentials
	alias Ueberauth.Auth.Extra

	 @doc """
  Handles the initial redirect to the github authentication page.

  To customize the scope (permissions) that are requested by github include them as part of your url:

      "/auth/github?scope=user,public_repo,gist"

  You can also include a `state` param that github will return to you.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)
    opts = [redirect_uri: callback_url(conn), scope: scopes]

    opts =
      if conn.params["state"], do: Keyword.put(opts, :state, conn.params["state"]), else: opts

    module = option(conn, :oauth2_module)
    redirect!(conn, apply(module, :authorize_url!, [opts]))
  end

  @doc """
  Handles the callback from Github. When there is a failure from Github the failure is included in the
  `ueberauth_failure` struct. Otherwise the information returned from Github is returned in the `Ueberauth.Auth` struct.
  """
  def handle_callback!(%Plug.Conn{ params: %{ "code" => code } } = conn) do
    module = option(conn, :oauth2_module)
    token = apply(module, :get_token!, [[code: code]])

    if token.access_token == nil do
      set_errors!(conn, [error(token.other_params["error"], token.other_params["error_description"])])
    else
      fetch_user(conn, token)
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc """
  Cleans up the private area of the connection used for passing the raw Github response around during the callback.
  """
  def handle_cleanup!(conn) do
    conn
    |> put_private(:discord_user, nil)
    |> put_private(:discord_token, nil)
  end

  @doc """
  Fetches the uid field from the Github response. This defaults to the option `uid_field` which in-turn defaults to `login`
  """
  def uid(conn) do
    conn.private.discord_user[option(conn, :uid_field) |> to_string]
  end

  @doc """
  Includes the credentials from the Github response.
  """
  def credentials(conn) do
    token = conn.private.discord_token
    scopes = (token.other_params["scope"] || "")
    |> String.split(",")

    %Credentials{
      token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type,
      expires: !!token.expires_at,
      scopes: scopes
    }
  end

  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  def info(conn) do
    user = conn.private.discord_user

    %Info{
    	id: user["id"],
    	username: user["username"],
    	discriminator: user["discriminator"],
    	avatar: user["avatar"],
    	verified: user["verified"],
    	email: user["email"],
    	mfa_enabled: user["mfa_enabled"]
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from the Github callback.
  """
  def extra(conn) do
    %Extra {
      raw_info: %{
        token: conn.private.discord_token,
        user: conn.private.discord_user
      }
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :discord_token, token)
    # Will be better with Elixir 1.3 with/else
    case OAuth2.AccessToken.get(token, "/users/@me") do
      { :ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])
      { :ok, %OAuth2.Response{status_code: status_code, body: user} } when status_code in 200..399 ->
        case OAuth2.AccessToken.get(token, "/users/@me") do
          { :ok, %OAuth2.Response{status_code: status_code, body: emails} } when status_code in 200..399 ->
            put_private(conn, :discord_user, user)
          { :error, _ } -> # Continue on as before
            put_private(conn, :discord_user, user)
        end
      { :error, %OAuth2.Error{reason: reason} } ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp option(conn, key) do
    Map.get(options(conn), key, Map.get(default_options(), key))
  end

end