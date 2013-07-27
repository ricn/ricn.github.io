---
layout: post
title: "Use UUIDs in Rails 4 with PostgreSQL"
date:   2013-07-27 21:00:00
categories: rails postgresql
---
<p class="lead">
	How to use UUIDs as Primary keys in Rails 4 with PostgreSQL
</p>

##### What are UUIDs anyway and why should you use them?

UUID stands for Universally Unique Identifier and the original purpose of UUIDs was to enable distributed systems to uniquely identify objects without significant central coordination. Anyone can create UUIDs and use them to identify something with reasonable confidence that the same identifier will never be unintentionally created by anyone to identify some other kind of object. 

Objects created with UUIDs can therefore later be merged into a single database without needing to resolve conflicts. 

Another advantage has to do with the randomness of UUIDs. UUIDs will not follow any kind of pattern so it's impossible for potential attackers to be able to go through your database records without you exposing a list of UUIDs. Of course, this doesn't automatically make your application secure, but it can reduce the damage that is likely to be done if a security bug is exploited.

##### Setup

Make sure you have the Rails 4 gem activated and PostgreSQL installed then run:

{% highlight bash %}
rails new uuids --database postgresql

# Edit database.yml to connect to your database.

rails generate migration enable_uuid_ossp_extension
rails generate model document title:string author:string

{% endhighlight %}

Then open the generated migration file named enable_uuid_ossp_extension and edit it so it looks like this:

{% highlight ruby %}
class EnableUuidOsspExtension < ActiveRecord::Migration
  def change
    enable_extension 'uuid-ossp'
  end
end
{% endhighlight %}

This will enable the [uuid-ossp](http://www.postgresql.org/docs/devel/static/uuid-ossp.html) module in PostgreSQL which provides functions to generate UUIDs.

Next we need to update the migration file named create_documents:

{% highlight ruby %}
class CreateDocuments < ActiveRecord::Migration
  def change
   create_table :documents, id: :uuid  do |t|
      t.string :title
      t.string :author
      t.timestamps
    end
  end
end
{% endhighlight %}

Note that we have explicitly changed the id to be a uuid type.

Now you're ready to create the database and run the migrations:
{% highlight bash %}
rake db:create
rake db:migrate
{% endhighlight %}

You can now open the Rails console and start playing with your document model:
{% highlight ruby %}
rails c

irb(main):011:0> Document.create(title: "PostgreSQL rocks!", author: "Richard N")
=> #<Document id: "33332e5a-dc83-48c9-ad92-28a99095b47b", title: "PostgreSQL rocks!", author: "Richard N", created_at: "2013-07-27 21:02:17", updated_at: "2013-07-27 21:02:17">
{% endhighlight %}
As you can see, your model now uses a UUID as a primary key instead of a simple integer. 

#### Gotchas
One thing that's not going to work anymore when you switch to UUIDs is the Document.first and Document.last class methods. To make them work again you can use the created_at attribute and define your own scopes in your model:

{% highlight ruby %}
class Document < ActiveRecord::Base
  scope :first, -> { order("created_at").first }
  scope :last, -> { order("created_at DESC").first }
end
{% endhighlight %}

Another thing that's not going to work anymore is the `t.references` method in migrations. If you write `t.references :document` for another table you create, it will create a `document_id` column with an `integer` as the type. This is not going to work because of obvious reasons. Instead you should define your relations using `t.uuid :document_id`.

Using UUIDs as primary keys has some drawbacks. They can be a little bit slower to generate and they requires bigger indexes compared to normal auto increment primary keys so you should consider that before using them.