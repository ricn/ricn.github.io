---
layout: post
title: "Validate uniqueness in Play 2"
date:   2013-10-23 21:00:00
categories: playframework java
---

If you create a unique index for a column it means you're guaranteed the table won't have more than one row with the same value for that column. You can enforce uniqueness in Ebean by setting unique=true when using the column annotation:

{% highlight java %}
  @Required
  @Column(unique=true)
  public String username;
{% endhighlight %}

Technically, this will save your ass if someone tries to create a new user with an existing username but it will only throw a PersistenceException:

{% highlight java %}
failed: javax.persistence.PersistenceException: ERROR executing DML bindLog[] error[Unique index or primary key violation: "UQ_USER_USER_NAME_INDEX_2 ON PUBLIC.USER(USER_NAME)"; SQL statement:\n insert into user (id, user_name, password_hash, active) values (?,?,?,?) [23505-172]]
{% endhighlight %}

Users (including developers) don't like to see exceptions so we need to create some sort of nice error message that we can show in the UI. To do this we can define an ad-hoc validation method in our model:

{% highlight java %}
public String validate() {
  User user = User.find.where().eq("username", username).findUnique();
  if (user != null && user.id != id) {
    return "Username " + username + " is already taken.";
  }
        
  return null;
}
{% endhighlight %}

When this method don't return null, a global error will be produced. To show this in your UI you can do this:
{% highlight scala %}
@if(userForm.hasGlobalErrors) {
    <div class="alert alert-error">@userForm.globalError.message</div>
}
{% endhighlight %}