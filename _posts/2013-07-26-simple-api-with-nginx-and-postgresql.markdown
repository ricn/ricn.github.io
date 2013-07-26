---
layout: post
title: "Simple API with Nginx and PostgreSQL"
date:   2013-07-26 16:53:00
categories: nginx postgresql
---
<p class="lead">
	How to build a simple REST API using only Nginx and PostgreSQL.
</p>

Sometimes it's overkill to use a web framework if you only need to develop a very simple REST API. It turns out that Nginx can be used to develop a full fledged REST API and PostgreSQL can easily be used for persistence.

In this blog post I'm going to show you how to create a simple CRUD API for articles.

#### Setup
I recommend that you use the [OpenResty](http://openresty.org) to install Nginx. It contains the standard Nginx core and lots of 3rd-party Nginx modules including the [Postgres upstream module](https://github.com/FRiCKLE/ngx_postgres/) that allows Nginx to communicate with a PostgreSQL database. OpenResty is not an Nginx fork, just a software bundle so there's nothing to worry about.

This is how I installed and compiled OpenResty on my Mac:

{% highlight bash %}
brew install pcre

tar xzvf ngx_openresty-1.4.1.1.tar.gz

cd ngx_openresty-1.4.1.1/

./configure \
--with-cc-opt="-I/usr/local/Cellar/pcre/8.33/include" \
--with-ld-opt="-L/usr/local/Cellar/pcre/8.33/lib" \
--with-http_postgres_module

{% endhighlight %}

Remember to change pcre version number to the one you have installed. It might differ.

For this blog post I used PostgreSQL 9.2. You can install PostgreSQL from [Homebrew](http://brew.sh) or use [Postgres.app](http://postgresapp.com) .

#### Create the database
{% highlight sql %}
CREATE DATABASE articledb WITH OWNER username ENCODING 'UTF8';

CREATE TABLE articles (
	id serial PRIMARY KEY,
 	title varchar(50) NOT NULL,
 	body varchar(32000) NOT NULL,
 	created_at timestamp DEFAULT current_timestamp
);

# add a few rows:
INSERT INTO articles (title, body) VALUES ('Test title 1', 'Test body 1');
INSERT INTO articles (title, body) VALUES ('Test title 2', 'Test body 2');
INSERT INTO articles (title, body) VALUES ('Test title 3', 'Test body 3');
{% endhighlight %}

#### The complete nginx.conf
{% highlight nginx %}
worker_processes 8;

events {}

http {
  upstream database {
    postgres_server 127.0.0.1 dbname=articledb user=username password=yourpass;
  }
  
  server {
    listen       8080;
    server_name  localhost;

    location /articles {
      postgres_pass database;
      rds_json on;
      postgres_query    HEAD GET  "SELECT * FROM articles";
      
      set $title $arg_title;
      set $body  $arg_body;
      postgres_query
        POST "INSERT INTO articles (title, body) VALUES('$title', '$body') RETURNING *";
      postgres_rewrite  POST changes 201;
    }

    location ~ /articles/(?<id>\d+) {
      postgres_pass database;
      rds_json  on;

      postgres_query    HEAD GET  "SELECT * FROM articles WHERE id='$id'";
      postgres_rewrite  HEAD GET  no_rows 410;

      set $title $arg_title;
      set $body  $arg_body;
      postgres_query
        PUT "UPDATE articles SET title='$title', body='$body' WHERE id='$id' RETURNING *";
      postgres_rewrite  PUT no_changes 410;

      postgres_query    DELETE  "DELETE FROM articles WHERE id='$id'";
      postgres_rewrite  DELETE  no_changes 410;
      postgres_rewrite  DELETE  changes 204;
    }
  }
}
{% endhighlight %}

#### Test drive the API

*Get all articles:*

{% highlight bash %}
curl http://localhost:8080/articles
{% endhighlight %}

*Create a new article:*

{% highlight bash %}
curl -X POST http://localhost:8080/articles?title=Article1&body=body1
{% endhighlight %}

*Update article:*
{% highlight bash %}
curl -X PUT http://localhost:8080/articles/1?title=Article2&body=body2
{% endhighlight %}

*Delete article:*
{% highlight bash %}
curl -X DELETE http://localhost:8080/articles/1
{% endhighlight %}