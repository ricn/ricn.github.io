---
layout: post
title: "PostgreSQL indexing in Elixir"
date:   2015-08-18 08:00:00
categories: elixir ecto postgresql
---
<p class="lead">
	The things you need to know about PostgreSQL indexes to keep your Elixir applications snappy.
</p>

The purpose of indexes is to make access to data faster. Most of the time an index will make your queries faster but the trade off is that for each index you have your data insertion will become slower. That's because when you insert data with an index it must write data to two different places.

PostgreSQL has many types of options when it comes to indexing. We will focus on the [B-tree](http://en.wikipedia.org/wiki/B-tree) index type which is the most commonly used index type for most use cases but we will can a look at the GIN (Generalized Inverted Index) index type
as well for indexing JSON columns.

You should be familiar with [Ecto](https://github.com/elixir-lang/ecto) and know how to work with [migrations](http://hexdocs.pm/ecto/Ecto.Migration.html) to follow this blog post.

#### Primary key indexes

Ok, let's start with the basics. In general it's a good practice to add an index for the primary key in your tables. If your table will have a large number of rows it makes good use of an index and the lookup will take place in the index instead of sequentially scan your table for the matching rows. Luckily, PostgreSQL automatically creates an index for primary keys to enforce uniqueness. Thus, it is not necessary to create an index explicitly for primary key columns:

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

As you can see, you now have an primary key index using the btree type to index the id column.

#### Foreign keys and other commonly used columns

Just like primary keys, foreign keys in your table will be indexed automatically in Ecto when you use the `references/2` function.
For other commonly used columns that need to be sorted, lookup fields and columns that are used with GROUP BY it's a good
idea to add indexes by using the `index/3` function.

Let's change our migration script to illustrate this:

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
Foreign-key constraints:
    "users_group_id_fkey" FOREIGN KEY (group_id) REFERENCES groups(id)
{% endhighlight %}

Notice that we now have an index called `users_dob_index` for the dob column. So that extra call to the `index/3` function
creates an index using btree for us. Also notice that now have a foreign constraint added as well. This index/constraint
is created when use the `references/2` function when adding columns to out table.

#### Unique Indexes

If you create a unique index for a column it means you're guaranteed the table won't have more than one row with the same value for that column. Using only `validates_uniqueness_of` validation in your model isn't enough to enforce uniqueness because there can be concurrent users trying to create the same data.

Imagine that two users tries to register an account with the same username where you have added `validates_uniqueness_of :username` in your user model. If they hit the "Sign up" button at the same time, Rails will look in the user table for that username and respond back that everything is fine and that it's ok to save the record to the table. Rails will then save the two records to the user table with the same username and now you have a really shitty problem to deal with.

To avoid this you need to create a unique constraint at the database level as well:
{% highlight ruby %}
class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :username
      ...
    end

    add_index :users, :username, unique: true
  end
end
{% endhighlight %}

In psql:
{% highlight sql %}
indexes_development=# \d users
                                  Table "public.users"
  Column  |          Type          |                     Modifiers
----------+------------------------+----------------------------------------------------
 id       | integer                | not null default nextval('users_id_seq'::regclass)
 username | character varying(255) |
Indexes:
    "users_pkey" PRIMARY KEY, btree (id)
    "index_users_on_username" UNIQUE, btree (username)
{% endhighlight %}

So by creating the `index_users_on_username` unique index you get two very nice benefits. Data integrity as descibed above and good performance because unique indexes tends to be very fast.

#### Sorted Indexes

By default, the entries in a B-tree index is sorted in ascending order. However, in some particular cases it can be a good idea to use a descending order for the index instead.

One of the most obvious case is when you have something that is paginated and all the items are sorted by the most recent released first. For example a blog post model that has a released_at column. For unreleased blog posts, the released_at value is NULL.

This is how you create this kind of index:

{% highlight ruby %}
class CreatePosts < ActiveRecord::Migration
  def change
    create_table :posts do |t|
      t.string :title
      t.datetime :released_at

      t.timestamps
    end

    add_index :posts, :released_at, order: { released_at: "DESC NULLS LAST" }
  end
end
{% endhighlight %}

As we're going to query the table in sorted order by released_at and limiting the result, we may have some benefit by creating an index in that order.
PostgreSQL will find the rows it needs from the index in the correct order, and then go to the data blocks to retrieve the data. If the index wasn't sorted, there's a good chance that PostgreSQL would read the data blocks sequentially and then sort the results.

This technique is mostly relevant with single column indexes when you require nulls to be last. Otherwise the order is already there because an index can be scanned in any direction.

#### Partial Indexes

If you frequently filter your queries by a particular column value, and that column value is present in a minority of your rows, partial indexes may increase your performance significantly.  A partial index is basically an index using a `WHERE` clause. It increases the efficiency of the index by reducing its size which makes the index smaller and takes less storage, is easier to maintain, and is faster to scan.

Let's say that you have a table for orders. That table can contain both billed and unbilled orders, where the unbilled orders take up a minority of the total rows in the table. It's very likely that the unbilled orders are also the most accessed rows in your application. Then it is very likely that your application performance will increase if you use an partial index.

Example:
{% highlight ruby %}
class CreateOrders < ActiveRecord::Migration
  def change
    create_table :orders do |t|
      t.float :amount
      t.boolean :billed, default: false

      t.timestamps
    end

    add_index :orders, :billed, where: "billed = false"
  end
end
{% endhighlight %}

This is how it looks in psql:

{% highlight sql %}
indexes_development-# \d orders
                                     Table "public.orders"
   Column   |            Type             |                      Modifiers
------------+-----------------------------+-----------------------------------------------------
 id         | integer                     | not null default nextval('orders_id_seq'::regclass)
 amount     | double precision            |
 billed     | boolean                     | default false
 created_at | timestamp without time zone |
 updated_at | timestamp without time zone |
Indexes:
    "orders_pkey" PRIMARY KEY, btree (id)
    "index_orders_on_billed" btree (billed) WHERE billed = false
{% endhighlight %}
