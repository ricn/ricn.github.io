---
layout: post
title: "Custom attributes in Rails 4 using PostgreSQL"
date:   2013-07-29 20:00:00
categories: rails postgresql
---

<p class="lead">
  How to add custom attributes to a model in Rails 4 using the hstore data type in PostgreSQL
</p>

Sometimes when we're developing an application we run into situations when we don't know exactly what types of attributes we need for a model.

One example might be model for contacts. A contact usually have fixed attributes like `first_name`, `last_name` and so on. But diffrent kind of contacts may have different kind of attributes like `referred_by` to keep track of who referred a customer to you. Or maybe you just want to keep track of a `customer_number`. Or maybe an attribute named `university` to keep track of which college a contact went to. The list of potential attributes that you can associate with a contact is endless and creating a column for all of them in a contact table will obviously not work.

This problem can easily be solved by using a data type named hstore in PostgreSQL. 

--END--

##### Setup

Make sure you have the Rails 4 gem activated and PostgreSQL installed then run:

{% highlight bash %}
rails new pgarrays --database postgresql

# Edit database.yml to connect to your database.

rails generate model document title tags

{% endhighlight %}

Next we need to update the migration file named create_documents:

{% highlight ruby %}
class CreateDocuments < ActiveRecord::Migration
  def change
    create_table :documents do |t|
      t.string :title
      t.string :tags, array: true, default: []
      t.timestamps
    end
  end
end
{% endhighlight %}

Note that we have added the `array: true` option to the tags attribute and that it defaults to an empty array.

Now you're ready to create the database and run the migrations:
{% highlight bash %}
rake db:create
rake db:migrate
{% endhighlight %}

If you open up `psql`, connects to your database and run `\d documents;`, you should see that your tags column has `[]` at the end which means it will be treated as an array:

{% highlight sql %}
Table "public.documents"
   Column   |            Type             |
------------+-----------------------------+------------------
 id         | integer                     | 
 title      | character varying(255)      | 
 tags       | character varying(255)[]    | 
 created_at | timestamp without time zone | 
 updated_at | timestamp without time zone |

Indexes:
    "documents_pkey" PRIMARY KEY, btree (id)
{% endhighlight %}

You can now open the Rails console and start playing with your document model:
{% highlight ruby %}
rails c

irb(main):001:0> Document.create(title: "PostgreSQL", tags: ["pg","rails"])
=> #<Document id: 1, title: "PostgreSQL", tags: ["pg", "rails"], created_at: "2013-07-28 13:21:43", updated_at: "2013-07-28 13:21:43">
{% endhighlight %}

As you can see, the tags property is now represented as an array. If you are curious about how it looks in PostgreSQL, use psql again:
{% highlight sql %}
pgarrays_development=# select * from documents;
 id |   title    |    tags    |        created_at         |        updated_at
----+------------+------------+---------------------------+---------------------------
  1 | PostgreSQL | {pg,rails} | 2013-07-28 13:21:43.78282 | 2013-07-28 13:21:43.78282
(1 row)

{% endhighlight %}


#### Querying
To query your documents you can use the Active Record query API as you normally do:

{% highlight ruby %}
# Find any record that has 'pg' stored in the tags array:
Document.where("'pg' = ANY (tags)")
=> #<ActiveRecord::Relation [#<Document id: 1, title: "PostgreSQL", tags: ["pg", "rails"]>, #<Document id: 2, title: "Rails", tags: ["pg", "rails"]>]>

{% endhighlight %}

#### Indexing
It's important to add an index for the tags column otherwise it's going to be slow as hell. You have the option to choose between two types of indexes called GiST and GIN. Which one that will suit you depends on how you want to use the tags. Your can read more about the two index types in the PostgreSQL documentation: [GiST and GIN Index Types](http://www.postgresql.org/docs/9.2/static/textsearch-indexes.html)

To add the index you can create this migration:
{% highlight ruby %}
class AddTagIndexToDocuments < ActiveRecord::Migration
  def change
    add_index  :documents, :tags, using: 'gin'
  end
end
{% endhighlight %}
