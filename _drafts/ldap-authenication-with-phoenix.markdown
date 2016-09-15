---
layout: post
title: "LDAP authentication with Phoenix"
categories: elixir phoenix ldap
---

##### Introduction

LDAP is mostly used by medium-to-large organi­zations to keep one centralized place to store users,  groups & to allow others systems to authenticate the users. If you want to build Elixir / Phoenix applications that will work within an enterprise you will likely have to integrate with an existing
LDAP server.

In this article I'm going to show you how you can authenticate & syncronize user information to your
Phoenix application.

##### Setup

Let's setup a new Phoenix project & a user model that we can use to demonstrate LDAP authentication in Phoenix:

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

To manage the authentication process I'm going to use Guardian which is one of the most popular authentication framework for use with Elixir applications. This article is not about Guardian so I'm not going to explain in detail what the code below does. If you're new to Guardian and want to know more you should read the documentation for Guardian.

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
  serializer: MyApp.GuardianSerializer
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
you can run mix phoenix.server and point your browser at localhost:4000 and you should just see the message 'Unauthenticated'. That's because the PageController is protected and we're not logged in yet.

##### Setup Exldap

To connect to an LDAP server and authenticate users I'm going to use the Exldap library. Exldap is
basically a thin wrapper for the eldap module in Erlang. To make everything a little bit easier we're
also going to use a public LDAP server with demo users.

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

The code above will give use access to forumsys public LDAP server which have a few users setup:
`einstein`, `newton`, `galieleo`, `tesla`, `riemann`, `gauss`, `euler`, `euclid`. All the users have the password `password`.

##### Develop our own LDAP module
* What do we need?
* Show the code
* Show the tests

##### Setup the SessionController and templates
