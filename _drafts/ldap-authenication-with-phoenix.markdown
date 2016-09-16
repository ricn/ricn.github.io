---
layout: post
title: "LDAP authentication with Phoenix"
categories: elixir phoenix ldap
---

##### Introduction

[LDAP](https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol) is mostly used by medium-to-large organi­zations to have one centralized place to store users and groups and to allow others internal systems to authenticate the users. If you want to build [Phoenix](http://http://www.phoenixframework.org/) applications that will work within an enterprise you will likely have to integrate with an existing LDAP server.

In this article I'm going to show you how you can authenticate and synchronize users to your Phoenix application.

##### Setup Phoenix

Let's setup a new Phoenix project and a user model that we can use to demonstrate LDAP authentication in Phoenix:

{% highlight bash %}
mix phoenix.new ldap_example
...
Fetch and install dependencies? [Yn] Y

cd ldap

mix ecto.create (configure your db in config/dev.exs if needed)

mix phoenix.gen.model User users username:string name:string email:string

mix ecto.migrate

{% endhighlight %}

##### Setup Guardian

To manage the authentication process I'm going to use [Guardian](https://hex.pm/packages/guardian) which is one of the most popular authentication framework for use with Elixir. This article is not about Guardian so I'm not going to explain in detail what the code below does. If you're new to Guardian and want to know more you should read the documentation for Guardian.

mix.exs:
{% highlight elixir %}
defp deps do
  [
    {:guardian, "~> 0.12.0"}
  ]
end
{% endhighlight %}

{% highlight bash %}
mix.deps.get
{% endhighlight %}

config/config.exs:
{% highlight elixir %}
config :guardian, Guardian,
  allowed_algos: ["HS512"], # optional
  verify_module: Guardian.JWT,  # optional
  issuer: "LdapExample",
  ttl: { 30, :days },
  verify_issuer: true, # optional
  secret_key: "NotSoSecretButWorksForADemo",
  serializer: LdapExample.GuardianSerializer
{% endhighlight %}

lib/ldap_example/guardian_serializer.ex:
{% highlight elixir %}
defmodule LdapExample.GuardianSerializer do
  @behaviour Guardian.Serializer
  alias LdapExample.User
  alias LdapExample.Repo

  def for_token(user = %User{}), do: { :ok, "User:#{user.id}" }
  def for_token(_), do: { :error, "Unknown resource type" }

  def from_token("User:" <> id), do: { :ok, Repo.get(User, id) }
  def from_token(_), do: { :error, "Unknown resource type" }
end
{% endhighlight %}

web/router.ex:
{% highlight elixir %}
defmodule LdapExample.Router do
  use LdapExample.Web, :router

  pipeline :browser_session do
    plug Guardian.Plug.VerifySession
    plug Guardian.Plug.LoadResource
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", LdapExample do
    pipe_through [:browser, :browser_session]

    get "/", PageController, :index
  end
end
{% endhighlight %}

web/controllers/page_controller.ex:
{% highlight elixir %}
defmodule LdapExample.PageController do
  use LdapExample.Web, :controller
  plug Guardian.Plug.EnsureAuthenticated

  def index(conn, _params) do
    render conn, "index.html"
  end
end
{% endhighlight %}

This is the basic setup for Guardian that we need to get started. To verify that everything works
you can run `mix phoenix.server` and point your browser at [http://localhost:4000](http://localhost:4000) and you should just see the message 'Unauthenticated'. That's because the PageController is now protected and we're not logged in yet.

##### Setup Exldap

To connect to an LDAP server and authenticate users I'm going to use the [Exldap](https://hex.pm/packages/exldap) library. Exldap is basically a thin wrapper for the [eldap](http://erlang.org/doc/man/eldap.html) module in Erlang. To make everything a little bit easier we're also going to use a public LDAP server with demo users from [Forumsystems](http://www.forumsys.com/en/tutorials/integration-how-to/ldap/online-ldap-test-server/) so we don't have to spend time setting up our own LDAP server for testing.

mix.exs:
{% highlight elixir %}
def deps do
  [{:exldap, "~> 0.2"}]
end
{% endhighlight %}

mix.exs:
{% highlight elixir %}
def application do
  [applications: [:exldap]]
end
{% endhighlight %}

config/config.exs (use config.secret.exs in a real applications):
{% highlight elixir %}
config :exldap, :settings,
  server: "ldap.forumsys.com",
  base: "dc=example,dc=com",
  port: 389,
  ssl: false,
  user_dn: "cn=read-only-admin,dc=example,dc=com",
  password: "password",
  search_timeout: 5_000
{% endhighlight %}

The code above will give us access to forumsys public LDAP server which have a few users setup:
`einstein`, `newton`, `galieleo`, `tesla`, `riemann`, `gauss`, `euler`, `euclid`. All the users have the password `password`.

##### Develop our own LDAP module
Now we have finally come to the part where we will implement a module to communicate with the LDAP server:

lib/ldap_example/ldap.ex:
{% highlight elixir %}
defmodule LdapExample.Ldap do

  def authenticate(uid, password) do
    {:ok, ldap_conn} = Exldap.open
    bind = "uid=#{uid},dc=example,dc=com"
    case Exldap.verify_credentials(ldap_conn, bind, password) do
      :ok -> :ok
      _ -> {:error, "Invalid username / password"}
    end
  end

  def get_by_uid(uid) do
    {:ok, ldap_conn} = Exldap.connect
    {:ok, search_results} = Exldap.search_field(ldap_conn, "uid", uid)
    case search_results do
      [] -> {:error, "Could not find user with uid #{uid}"}
      _ -> search_results |> Enum.fetch(0)
    end
  end

  def to_map(entry) do
    username = Exldap.search_attributes(entry, "uid")
    name = Exldap.search_attributes(entry, "cn")
    email = Exldap.search_attributes(entry, "mail")
    %{username: username, name: name, email: email}
  end
end
{% endhighlight %}

The `authenticate` function takes an uid and a password as arguments so we can authenticate the user. uid stands for user id in LDAP and is used as the computer system login name. The function opens a connection to the LDAP server and verifies the credentials.

The `get_by_uid` function is used to search for the object with a specified uid in LDAP. We'll use this function later to synchronize username, name & email to our local PostgreSQL database. Even though we have the information in LDAP we probably want to have a local table with our users
so we can have real database relationships with other tables in our application.

The `to_map` functions is just a helper function which transforms an ldap_entry to a map with more sane keys names that we use in our local database.

##### Setup the SessionController and templates
To authenticate users in Phoenix we need to create a very basic GUI and a Session controller to
handle sign in and sign out scenarios.

web/controllers/session_controller.ex:
{% highlight elixir %}
defmodule LdapExample.SessionController do
  use LdapExample.Web, :controller
  alias LdapExample.{User, Repo, Ldap}

  def new(conn, _params) do
    render conn, "new.html", changeset: User.login_changeset
  end

  def create(conn, %{"user" => params}) do
    username = params["username"]
    password = params["password"]
    case Ldap.authenticate(username, password) do
      :ok -> handle_sign_in(conn, username)
      _   -> handle_error(conn)
    end
  end

  defp handle_sign_in(conn, username) do
    {:ok, user} = insert_or_update_user(username)
    conn
    |> put_flash(:info, "Logged in.")
    |> Guardian.Plug.sign_in(user)
    |> redirect(to: page_path(conn, :index))
  end

  defp insert_or_update_user(username) do
    {:ok, ldap_entry} = Ldap.get_by_uid(username)
    user_attributes = Ldap.to_map(ldap_entry)
    user = Repo.get_by(User, username: username)
    changeset =
      case user do
        nil -> User.changeset(%User{}, user_attributes)
        _ -> User.changeset(user, user_attributes)
      end
    Repo.insert_or_update changeset
  end

  defp handle_error(conn) do
    conn
    |> put_flash(:error, "Wrong username or password")
    |> redirect(to: session_path(conn, :new))
  end

  def delete(conn, _params) do
    Guardian.Plug.sign_out(conn)
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: "/")
  end
end
{% endhighlight %}

The interesting parts in the Session controller happens in the `create`, `handle_sign_in` and `insert_or_update` function. In the `create` function we just authenticate the user with username / password using our own Ldap module. If the user is authenticated in LDAP we continue to the
`handle_sign_in` function and calls the `insert_or_update` function. That function just gets the user attributes from LDAP and creates a map that we can use when we create an Ecto changeset. The changeset
deals with all the details and determines if we need to insert the user (first time sign in) or just update it. The user will only be updated if the attributes in LDAP differs from the attributes in our
local user table.

web/model/user.ex:
{% highlight elixir %}
defmodule LdapExample.User do
  use LdapExample.Web, :model

  schema "users" do
    field :username, :string
    field :name, :string
    field :email, :string
    field :password, :string, virtual: true
    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:username, :name, :email])
    |> validate_required([:username, :name, :email])
  end

  def login_changeset do
    %__MODULE__{} |> cast(%{}, ~w(username password), ~w())
  end
end
{% endhighlight %}
The user model has just been updated with a virtual field for password and a special login_changeset
that we use in the sign in form.

web/templates/session/new.html.eex:
{% highlight erb %}
<h2>Sign in</h2>
<%= form_for @changeset, session_path(@conn, :create), [method: :post], fn f -> %>
  <div class="form-group">
    <label>Username</label>
    <%= text_input f, :username, class: "form-control" %>
  </div>

  <div class="form-group">
    <label>Password</label>
    <%= password_input f, :password, class: "form-control" %>
  </div>

  <div class="form-group">
    <%= submit "Sign in", class: "btn btn-primary" %>
  </div>
<% end %>
{% endhighlight %}

web/view/session_view.ex:
{% highlight elixir %}
defmodule LdapExample.SessionView do
  use LdapExample.Web, :view
end
{% endhighlight %}

web/router.ex
{% highlight elixir %}
...
get "/sign_in", SessionController, :new
post "/sign_in", SessionController, :create
get "/sign_out", SessionController, :delete
...
{% endhighlight %}

And finally we need to add our Session controller to the router. Now you can try to start your Phoenix application and point your browser to [http://localhost:4000/sign_in](http://localhost:4000/sign_in) and try to login with einstein / password. You should now see the default Phoenix page and a message saying that you're logged in. To sign out again you can just point your browser to [http://localhost:4000/sign_out](http://localhost:4000/sign_out) and
you should see the Unauthenticated message again.

##### Conclusion

Implementing LDAP authentication and synchronization with Elixir / Phoenix was much more straight forward than I thought. The library support is already in place thanks to Guardian and Exldap and if you want dig deeper and implement more advanced things you can always fall back to the eldap library in Erlang which seems to have virtually everything you need to work with LDAP.

It also worth mentioning that there are another LDAP library in Elixir which integrates nicely with Ecto called [EctoLdap](https://hex.pm/packages/ecto_ldap).

Happy LDAPing!
