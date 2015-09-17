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
that needs to be displayed in the web browser. Although response times in [Phoenix](http://www.phoenixframework.org/) are often measured in microseconds instead of milliseconds it will take some time for the browser to render all the HTML over and over again and
if you have a logo in the header you will see it flickering.

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
