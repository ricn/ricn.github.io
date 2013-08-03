---
layout: post
title: "Custom fields in Rails using PostgreSQL"
date:   2013-08-03 20:00:00
categories: rails postgresql
---

<p class="lead">
  How to add custom fields to a model in Rails using the hstore data type in PostgreSQL
</p>

Sometimes when we're developing an application we run into situations when we don't know exactly what types of fields we need for a model.

One example might be a model for contacts. A contact usually have fixed fields like `first_name`, `last_name` and so on. But diffrent kind of contacts may have different kind of fields like `referred_by` to keep track of who referred a customer to you. Or maybe you just want to keep track of a `customer_number`. Or maybe a field named `university` to keep track of which college a contact went to. The list of potential fields that you can associate with a contact is endless and creating a column for all of them in a contact table will obviously not work.

This problem can easily be solved by using a data type named hstore in PostgreSQL which allows you to store key/value structures just like a dictionary or hash.

##### Setup

Make sure you have the Rails 4 gem activated and PostgreSQL installed then run:

{% highlight bash %}
rails new hstore --database postgresql

# Edit database.yml to connect to your database.

rails generate migration enable_hstore_extension

rails generate model contact first_name last_name fields:hstore

{% endhighlight %}

Then open the generated migration file named enable_hstore_extension and edit it so it looks like this:
{% highlight ruby %}
class EnableHstoreExtension < ActiveRecord::Migration
  def change
    enable_extension 'hstore'
  end
end
{% endhighlight %}

You also have migration file looking like this:

{% highlight ruby %}
class CreateContacts < ActiveRecord::Migration
  def change
    create_table :contacts do |t|
      t.string :first_name
      t.string :last_name
      t.hstore :fields

      t.timestamps
    end
  end
end
{% endhighlight %}

Notice that we now can use the data type hstore within an migration.

Now you're ready to create the database and run the migrations:
{% highlight bash %}
rake db:create
rake db:migrate
{% endhighlight %}

If you open up `psql`, connects to your database and run `\d contacts;`, you should see your fields column:

{% highlight sql %}
Table "public.contacts"

   Column   |            Type             |
------------+-----------------------------+
 id         | integer                     |
 first_name | character varying(255)      | 
 last_name  | character varying(255)      | 
 fields     | hstore                      | 
 created_at | timestamp without time zone | 
 updated_at | timestamp without time zone | 
{% endhighlight %}

You can now open the Rails console and start playing with your contact model:
{% highlight ruby %}
rails c

irb(main):001:0> c = Contact.create(first_name: "Richard", last_name: "Nystrom", fields: { university: "LIU", age: 29 })
=> #<Contact id: 1, first_name: "Richard", last_name: "Nystrom", fields: {:univeristy=>"LIU", :age=>29}>
irb(main):001:0> c.reload
irb(main):001:0> c.fields
=> {"age"=>"29", "university"=>"LIU"}
{% endhighlight %}

One important thing to be aware of here is the difference about the hash that's returned from the database is that the keys and values are all strings, even though we used a symbol and an integer for the age when we set it. At the moment, hstore only stores string values so if we want to store a boolean, date or integer value we’ll need to convert it manually afterwards. 

Another important thing to remember is that the fields object will be a different object each time we fetch it. We cannot set a specific field through this hash. It won't work as the old hash will be used each time. We always have to set the full hash each time.

If you are curious about how the row looks like the the database you can use psql and run:

{% highlight sql %}
hstore_development=# select * from contacts;
 id | first_name | last_name |              fields              |
----+------------+-----------+----------------------------------+
  1 | Richard    | Nystrom   | "age"=>"29", "univeristy"=>"LIU" |
(1 row)
{% endhighlight %}

#### Querying

Here's some sample queries:

{% highlight ruby %}
# Find all contacts that have a key of 'age' in fields
Contact.where("fields ? 'age'")

# Find all contacts that have a 'age' and '29' key value pair in fields
Contact.where("fields @> ('age => 29')")

# Find all contacts that don't have a key value pair 'age' and '29' in fields
Contact.where("not fields @> ('age => 29')")

# Find all contacts having key 'university' and value like 'LI' in fields
Contact.where("fields -> 'university' LIKE '%LI%'")
{% endhighlight %}

More information about the hstore operators and functions can be found [here](http://www.postgresql.org/docs/9.2/static/hstore.html) .

#### Indexing
If you query for data frequently in your hstore column you should add an index for the data. You have the option to choose between two types of indexes called GiST and GIN. Which one that will suit you depends on how you want to use your data in your hstore column. Your can read more about the two index types in the PostgreSQL documentation: [GiST and GIN Index Types](http://www.postgresql.org/docs/9.2/static/textsearch-indexes.html)

To add the index you can create this migration:
{% highlight ruby %}
class AddFieldsIndexToContacts < ActiveRecord::Migration
  def change
    add_index :contacts, :fields, using: 'gin'
  end
end
{% endhighlight %}