---
layout: post
title: "Develop blazing fast web apps in Phoenix using PJAX"
date:   2015-09-20 08:00:00
categories: elixir phoenix
---
<p class="lead">
  Turbolinks for Phoenix [trollface]
</p>

Frameworks and libraries like [AngularJS](https://angularjs.org/), [Ember](http://emberjs.com/) and [React](https://facebook.github.io/react/) are very popular choices for modern frontend development. While
they are great for building complex user interfaces they also adds extra complexity to your web application.

The old school alternative is to just use pure server-side frameworks that spits out all the HTML on each request.
This approach is very simple to reason about while you develop your web application because you just have to send all HTML
that needs to be displayed in the web browser. Although response times in [Phoenix](http://www.phoenixframework.org/) are often measured in microseconds instead of milliseconds it will take some time for the browser to render all the HTML over and over again and if you have a logo in the header you will see it flickering.

[PJAX](https://github.com/defunkt/jquery-pjax) is a [jQuery](https://jquery.com/) plugin, written by [Chris Wanstrath]() that puts itself somewhere between client side and server side rendering of HTML. The idea behind PJAX is that you update only the parts of the page that change when the user navigates through your app. However, unlike a normal AJAX app that returns only data (JSON) from the server, a PJAX request actually contains normal HTML that has been generated on the server. This HTML is only a fragment of the full page and using Javascript on the client this fragment is substituted in for the last page's content.

##### Setup

Let's setup a new Phoenix project that we can use to demonstrate PJAX in Phoenix:

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

##### Test your new web application

If you click around in your new application you will probably notice that the Phoenix logo is flickering. Also, look in your log file and remember how long time it takes for Phoenix to send a 200 OK for the HTML. On my old Macbook Air i7 from 2012 it takes 1ms to render /users/new without PJAX. That's of course already ridicoulsy fast for running the Phoenix server in developement mode. Once I enable PJAX in the application, Phoenix responds in ~700µs instead.

Around 300ms to load everything
30 ms with PJAX in Chrome.

##### Implement PJAX in your new web application

PJAX is not fully automatic. You'll need to setup and choose a containing element on your page that will be replaced when you click on links in your web application.

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

You only see the body part of the layout above. Notice that we have added a div with id pjax-container. We want PJAX to grab the URLs that will be rendered in @inner then replace #pjax-container with whatever it gets back. No styles or scripts will be reloaded. Also notice that we have added links to jQuery and the PJAX library at the bottom of the body.

Next we need to initialize PJAX when you hit the web app for the first time:

{% highlight javascript %}
// web/static/js/app.js
import "deps/phoenix_html/web/static/js/phoenix_html"

$(function () {
  $(document).pjax("a", "#pjax-container");
});
{% endhighlight %}

This means that all a-tags within the #pjax-container will be loaded used as a pjax-link and load the url content using
ajax.

Now, we are getting closer to a complete solution. But we still needs to tell the server to not render & send the layout
to the client. This can easily be done by creating a custom plug in Phoenix:
