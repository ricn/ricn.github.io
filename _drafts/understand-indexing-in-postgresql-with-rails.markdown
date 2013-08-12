---
layout: post
title: "PostgreSQL indexing in Rails"
date:   2013-08-12 21:00:00
categories: rails postgresql
---
<p class="lead">
	The things you need to know about PostgreSQL indexes to keep your Rails applications snappy.
</p>

Reading about indexing can be a little bit boring but the truth is that to create a snappy Rails application you need to create effective indexes for your database.
PostgreSQL has many types of options when it comes to indexing. The one we're going to focus on in this article is the B-tree index type which is the most commonly used index type for most use cases.

#### Primary key indexes

Ok, let's start with the basics. In general it's a good practice to add an index for the primary key in your tables. If your table will have a large number of rows it makes good use of an index and the lookup will take place in the index instead of sequentially scan your table for the matching rows. Luckily, PostgreSQL automatically creates an index for primary keys to enforce uniqueness. Thus, it is not necessary to create an index explicitly for primary key columns.

If you run the migration below...
{% highlight ruby %}
class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :name
    end	
  end
end
{% endhighlight %}

...your table description will look like this in psql:

{% highlight sql %}
indexes_development=# \d products
                                 Table "public.products"
 Column |          Type          |                       Modifiers
--------+------------------------+-------------------------------------------------------
 id     | integer                | not null default nextval('products_id_seq'::regclass)
 name   | character varying(255) | 
Indexes:
    "products_pkey" PRIMARY KEY, btree (id)
{% endhighlight %}

As you can see, you now have an primary key index using the btree type to index the id column.

#### Foreign keys and other commonly used columns

Unlike primary keys, foreign keys and other columns in your table will not be indexed automatically in Rails. So it's always a good idea to add indexes for foreign keys, columns that need to be sorted, lookup fields and columns that are used with the `group` method (GROUP BY) in the [Active Record Query Interface](http://guides.rubyonrails.org/active_record_querying.html).

One of the most common performance problem with rails applications is the lack of indexes on foreign keys. Luckily it's very easy to avoid this pitfall:

{% highlight ruby %}
class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :name
     	t.belongs_to :category
    end

    create_table :categories do |t|
      t.string :name
    end

    add_index :products, :category_id
  end
end
{% endhighlight %}

And after adding the migration above you should see this in psql:

{% highlight sql %}

indexes_development=# indexes_development=# \d products
                                   Table "public.products"
   Column    |          Type          |                       Modifiers
-------------+------------------------+-------------------------------------------------------
 id          | integer                | not null default nextval('products_id_seq'::regclass)
 name        | character varying(255) | 
 category_id | integer                | 
Indexes:
    "products_pkey" PRIMARY KEY, btree (id)
    "index_products_on_category_id" btree (category_id)

{% endhighlight %}

Notice that we now have an index called `index_products_on_category_id` for the category_id. So that extra `add_index` line in the migration will make your application perform a lot better.

#### Unique Indexes

If you create a unique index for a column it means you're guaranteed the table won't have more than one row with the same value for that column. Using only `validates_uniqueness_of` validation in your model isn't enough to enforce uniqueness because there can be concurrent users trying to create the same data.

Imagine that two users tries to register an account with the same username where you have set `validates_uniqueness_of :username` in your user model. If they hit the "Sign up" button at the same time Rails will look in the user table for that username and respond back that everything is fine and that it's ok to save the record to the table. Rails will then save the two records to the user table with the same username and you now have a really shitty problem to deal with.

To avoid this you need to create a unique constraint at the database level as well. Typical columns that should have unique indexes are username or e-mail for logins:



So by using this kind of index you get two very nice benefits. Data integrity as descibed above and you also get good performance because unique indexes tends to be very fast.

#### Sorted Indexes
By default, the entries in a B-tree index is sorted in ascending order.

In some cases it makes sense to supply a different sort order for an index. Take the case when you’re showing a paginated list of articles, sorted by most recent published first. We may have a published_at column on our articles table. For unpublished articles, the published_at value is NULL.


In this case we can create an index like so:

Since we will be querying the table in sorted order by published_at and limiting the result, we may get some benefit out of creating an index in the same order. Postgres will find the rows it needs from the index in the correct order, and then go to the data blocks to retrieve the data. If the index wasn’t sorted, there’s a good chance that Postgres would read the data blocks sequentially and sort the results.

This technique is mostly relevant with single column indexes when you require “nulls to sort last” behavior, because otherwise the order is already available since an index can be scanned in any direction. It becomes even more relevant when used against a multi-column index when a query requests a mixed sort order, like a ASC, b DESC.

#### Multi-column Indexes

While Postgres has the ability to create multi-column indexes, it’s important to understand when it makes sense to do so. The Postgres query planner has the ability to combine and use multiple single-column indexes in a multi-column query by performing a bitmap index scan. In general, you can create an index on every column that covers query conditions and in most cases Postgres will use them, so make sure to benchmark and justify the creation of a multi-column index before you create them. As always, indexes come with a cost, and multi-column indexes can only optimize the queries that reference the columns in the index in the same order, while multiple single column indexes provide performance improvements to a larger number of queries.

However there are cases where a multi-column index clearly makes sense. An index on columns (a, b) can be used by queries containing WHERE a = x AND b = y, or queries using WHERE a = x only, but will not be used by a query using WHERE b = y. So if this matches the query patterns of your application, the multi-column index approach is worth considering. Also note that in this case creating an index on a alone would be redundant.

#### Partial Indexes

#### Expression Indexes