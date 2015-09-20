---
layout: post
title: "Develop fast web apps in Phoenix using pjax"
date:   2015-09-20 08:00:00
categories: elixir phoenix
---

##### Introduction

Frameworks and libraries like [AngularJS](https://angularjs.org/), [Ember](http://emberjs.com/) and [React](https://facebook.github.io/react/) are very popular choices for modern frontend development today. While they are great for building complex user interfaces they also adds extra complexity to your web application.

The old school alternative is to just use pure server-side rendering that spits out all the HTML on each request.
This approach is very simple to reason about while you develop your web application because you just have to send all HTML
that needs to be displayed in the web browser all the time. Although response times in [Phoenix](http://www.phoenixframework.org/) are often measured in microseconds instead of milliseconds it will take some time for the browser to render all the HTML over and over again and if you have a logo in the header you will see it flickering.

[Pjax](https://github.com/defunkt/jquery-pjax) is a [jQuery](https://jquery.com/) plugin, written by [Chris Wanstrath]() that puts itself somewhere between client side and server side rendering of HTML. The idea behind pjax is that you update only the parts of the page that change when the user navigates through your app. However, unlike a normal AJAX app that returns only JSON from the server, a pjax request actually contains normal HTML that has been generated on the server. This HTML is only a fragment of the full page and Javascript is used in the browser to add the content to the page.

In this article I'm going to show you how you can add pjax to the Phoenix framework.

##### Setup

Let's setup a new Phoenix project that we can use to demonstrate pjax in Phoenix:

{% highlight bash %}
mix phoenix.new pjax
...
Fetch and install dependencies? [Yn] Y

cd pjax

mix ecto.create (configure your db in config/dev.exs if needed)

mix phoenix.gen.html User users name:string age:integer
(don't forget to add resources "/users", UserController to web/router.ex)

mix ecto.migrate

mix phoenix.server
{% endhighlight %}

You should now have a simple crud app up and running in Phoenix. Point your browser at http://localhost:4000/users.

##### Test your new web application without pjax

If you click around in your new application you will probably notice that the Phoenix logo is flickering. Also, look in your log file and remember how long time it takes for Phoenix to send a 200 OK for the HTML. On my old Macbook Air i7 from 2012 it takes ~1ms to render /users/new without pjax. That's of course already ridiculously fast for running the Phoenix server in developement mode. When I look in the Chrome console it takes around
300ms to load everything when I visit /users/new. We will compare this with pjax enabled later in the article.

##### Implement pjax in your new web application

Pjax is not fully automatic. You'll need to setup and choose a containing element on your page that will be replaced when you click on links in your web application.

First we need to change our layout file:

{% highlight erb %}
## web/templates/layout/app.html.eex
...
<div class="container" role="main">
  <div class="header">
    <ul class="nav nav-pills pull-right">
      <li><a href="http://www.phoenixframework.org/docs">Get Started</a></li>
    </ul>
    <span class="logo"></span>
  </div>

  <div id="pjax-container">
    <p class="alert alert-info" role="alert"><%= get_flash(@conn, :info) %></p>
    <p class="alert alert-danger" role="alert"><%= get_flash(@conn, :error) %></p>
    <%= @inner %>
  </div>

</div> <!-- /container -->
<script src="//cdnjs.cloudflare.com/ajax/libs/jquery/2.1.4/jquery.min.js"></script>
<script src="//cdnjs.cloudflare.com/ajax/libs/jquery.pjax/1.9.6/jquery.pjax.min.js"></script>
<script src="<%= static_path(@conn, "/js/app.js") %>"></script>
...
{% endhighlight %}

You only see the body part of the layout above. The rest is omitted to save space. Notice that we have added a div with id pjax-container. We want pjax to grab the URLs that will be rendered in `@inner` then replace `#pjax-container` with whatever it gets back from the server. No styles or scripts will be reloaded. Also notice that we have added links to jQuery and the pjax library at the bottom of the body.

Next we need to initialize pjax when the user hit the web app for the first time:

{% highlight javascript %}
// web/static/js/app.js
...

$(function () {
  $(document).pjax("a", "#pjax-container");
});
{% endhighlight %}

This means that all a tags within the #pjax-container will be used as a pjax-link and load the url content using
ajax.

Now, we are getting closer to a complete solution. But we still need to tell the server to not render and send the layout
to the client. This can easily be done by creating a custom plug in Phoenix:

{% highlight elixir %}
## web/plugs/pjax.ex
defmodule Pjax.Plugs.Pjax do
  import Plug.Conn
  use Phoenix.Controller

  def init(default), do: default

  def call(conn, default) do
    use_pjax? = Enum.any?(conn.req_headers, fn(x) -> {"x-pjax", "true"} == x end)
    if use_pjax?, do: conn |> put_layout(false), else: conn
  end
end
{% endhighlight %}

This simple plug just looks for the x-pjax request header that will be added by the jQuery plugin when we click on a link.
If the header is present we tell Phoenix to not put any layout by using `put_layout(false)`. Otherwise we just return the conn as is.

The last thing we need to do is to add the plug to the browser stack:

{% highlight elixir %}
## web/router.ex
...
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_flash
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug Pjax.Plugs.Pjax
end
...
{% endhighlight %}

Don't forget to restart your server.

##### Test your new web application with pjax

Now when you click around in your application you should notice that the logo is not flickering anymore and the overall experience is that application is a whole lot faster. If I look in my log file I can now see that it takes ~700µs to to render /users/new with pjax enabled. That's 300 µs faster than without pjax. That's not so much of an improvement.

However, when I look in the Chrome console it only takes ~30ms to handle the AJAX request and to render the HTML fragment. That's a significant improvement in my opinion (compared to ~300ms).

##### Conclusion

One of the biggest advantage with pjax is simplicity in my mind. I like full client-side frameworks like AnguarJS and React but sometimes it's just
too complicated. The pjax approach allows you to use the good ol' server side rendering you are familiar with while still getting great client-side performance. As with most design choices, there are trade-offs. This approach isn't for every app, but it is a great tool to have available and use when appropriate.
