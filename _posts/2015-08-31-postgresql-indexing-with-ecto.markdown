---
layout: post
title: "PostgreSQL indexing with Ecto"
date:   2015-08-31 08:00:00
categories: elixir ecto postgresql
---
<p class="lead">
	The things you need to know about PostgreSQL indexes to keep your Elixir applications snappy.
</p>

The purpose of indexes is to make access to data faster. Most of the time an index will make your queries faster but the trade off is that for each index you have your data insertion will become slower. That's because when you insert data with an index it must write data to two different places.

PostgreSQL has many types of options when it comes to indexing. We will focus on the [B-tree](http://en.wikipedia.org/wiki/B-tree) index type which is the most commonly used index type for most use cases.

You should be familiar with [Ecto](https://github.com/elixir-lang/ecto) and know how to work with [migrations](http://hexdocs.pm/ecto/Ecto.Migration.html) to follow this blog post.

#### Primary key indexes

Ok, let's start with the basics. In general it's a good practice to add an index for the primary key in your tables. If your table will have a large number of rows it makes good use of an index and the lookup will take place in the index instead of sequentially scan your table for the matching rows. Luckily, PostgreSQL automatically creates an index for primary keys to enforce uniqueness. Thus, it is not necessary to create an index explicitly for primary key columns.

Let's create a basic table:

{% highlight elixir %}
defmodule EctoIndex.Repo.Migrations.AddTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :full_name, :string
    end
  end
end
{% endhighlight %}

...your table description will look like this in psql:

{% highlight sql %}
ecto_index=# \d users
                                  Table "public.users"
  Column   |          Type          |                     Modifiers
-----------+------------------------+----------------------------------------------------
 id        | integer                | not null default nextval('users_id_seq'::regclass)
 full_name | character varying(255) |
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
{% endhighlight %}

As you can see, you now have a primary key index using the btree type to index the id column.

#### Foreign keys and other commonly used columns

Unlike primary keys, foreign keys and other columns in your table will not be indexed automatically in PostgreSQL. So it’s always a good idea to add indexes for foreign keys, columns that need to be sorted, lookup fields and columns that are used with `GROUP BY`.

Luckily it’s very easy to add them. Let's change our migration script to illustrate this:

{% highlight elixir %}
defmodule EctoIndex.Repo.Migrations.AddTables do
  use Ecto.Migration

  def change do
    create table(:groups) do
      add :name, :string
    end

    create table(:users) do
      add :full_name, :string
      add :dob, :date
      add :group_id, references(:groups)
    end

    create index(:users, [:group_id])
    create index(:users, [:dob])
  end
end

{% endhighlight %}

And after adding the migration above you should see this in psql:

{% highlight sql %}
ecto_index=# \d users
                                  Table "public.users"
  Column   |          Type          |                     Modifiers
-----------+------------------------+----------------------------------------------------
 id        | integer                | not null default nextval('users_id_seq'::regclass)
 full_name | character varying(255) |
 dob       | date                   |
 group_id  | integer                |
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
    "users_dob_index" btree (dob)
    "users_group_id_index" btree (group_id)
Foreign-key constraints:
    "users_group_id_fkey" FOREIGN KEY (group_id) REFERENCES groups(id)
{% endhighlight %}

Notice that we now have an index called `users_dob_index` for the dob column. So that extra call to the `index/3` function
creates an index using btree for us. Also notice that we now have foreign constraint and an index for the group_id column.

#### Unique Indexes

If you create a unique index for a column it means you're guaranteed the table won't have more than one row with the same value for that column.
Unique indexes are typical for things like username or email that's used to login to an application.

This is how you create a unique index with Ecto:

{% highlight elixir %}
defmodule EctoIndex.Repo.Migrations.AddTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string
    end

    create unique_index(:users, [:email])
  end
end
{% endhighlight %}

In psql:
{% highlight sql %}
ecto_index=# \d users
                                 Table "public.users"
 Column |          Type          |                     Modifiers
--------+------------------------+----------------------------------------------------
 id     | integer                | not null default nextval('users_id_seq'::regclass)
 email  | character varying(255) |
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
    "users_email_index" UNIQUE, btree (email)
{% endhighlight %}

So by creating the `users_email_index` unique index you get some very nice benefits like data integrity and good performance because unique indexes tends to be very fast. You also get the possibility to use the `unique_constraint/3` function in changesets:

{% highlight elixir %}
	cast(user, params, ~w(email), ~w()) |> unique_constraint(:email)
{% endhighlight %}

The validation function relies on the database to check if the unique constraint has been violated or not and, if so, Ecto converts it into a changeset error which is much nicer to present to the end user.

#### Sorted Indexes

By default, the entries in a B-tree index is sorted in ascending order. However, in some particular cases it can be a good idea to use a descending order for the index instead.

One of the most obvious case is when you have something that is paginated and all the items are sorted by the most recent created first. For example a blog post model that has a released_at column. For unreleased blog posts, the released_at value is NULL.

This is how you create this kind of index:

{% highlight elixir %}
defmodule EctoIndex.Repo.Migrations.AddTables do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :title, :string
      add :released_at, :datetime
    end

    create index(:posts, ["released_at DESC NULLS LAST"])
  end
end
{% endhighlight %}

In psql:

{% highlight sql %}
ecto_index=# \d posts
                                      Table "public.posts"
   Column    |            Type             |                     Modifiers
-------------+-----------------------------+----------------------------------------------------
 id          | integer                     | not null default nextval('posts_id_seq'::regclass)
 title       | character varying(255)      |
 released_at | timestamp without time zone |
Indexes:
    "posts_pkey" PRIMARY KEY, btree (id)
    "posts_released_at_DESC_NULLS_LAST_index" btree (released_at DESC NULLS LAST)
{% endhighlight %}

As we're going to query the table in sorted order by released_at and limiting the result, we may have some benefit by creating an index in that order. PostgreSQL will find the rows it needs from the index in the correct order, and then go to the data blocks to retrieve the data. If the index wasn't sorted, there's a good chance that PostgreSQL would read the data blocks sequentially and then sort the results.

This technique is mostly relevant with single column indexes when you require nulls to be last. Otherwise the order is already there because an index can be scanned in any direction.

#### Partial Indexes

If you frequently filter your queries by a particular column value, and that column value is present in a minority of your rows, partial indexes may increase your performance significantly. A partial index is basically an index using a `WHERE` clause. It increases the efficiency of the index by reducing its size which makes the index smaller and takes less storage, is easier to maintain, and is faster to scan.

Let's say that you have a table for orders. That table can contain both billed and unbilled orders, where the unbilled orders take up a minority of the total rows in the table. It's very likely that the unbilled orders are also the most accessed rows in your application. Then it is very likely that your application performance will increase if you use an partial index.

Example:
{% highlight elixir %}
defmodule EctoIndex.Repo.Migrations.AddTables do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add :billed, :boolean, default: false
    end

    execute("CREATE INDEX index_orders_on_billed_idx ON orders(billed) WHERE billed = false")
  end
end
{% endhighlight %}

This is how it looks in psql:

{% highlight sql %}
ecto_index=# \d orders
                         Table "public.orders"
 Column |  Type   |                      Modifiers
--------+---------+-----------------------------------------------------
 id     | integer | not null default nextval('orders_id_seq'::regclass)
 billed | boolean | default false
Indexes:
    "orders_pkey" PRIMARY KEY, btree (id)
    "index_orders_on_billed_idx" btree (billed) WHERE billed = false
{% endhighlight %}

Ecto does not have any nice feature to define partial indexes yet so we have to rely on the `execute/1` function and send
the raw command to PostgreSQL. I have created an [issue on Github](https://github.com/elixir-lang/ecto/issues/883) for this and it's currently being discussed and hopefully we can have some nice syntax for defining partial indexes in Ecto soon.
