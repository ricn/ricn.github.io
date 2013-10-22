---
layout: post
title: "Better password hashing in Play 2.2 (Java)"
date:   2013-10-22 08:00:00
categories: playframework bcrypt
---

#### Why not just use good ol' MD5, SHA1 or SHA256?

MD5, SHA1 and SHA256 was not created for password hashing to begin with. They were created to calculate a digest for a huge amount of data where performance is high priority. This means that they are perfect for ensuring the integrity of data but very bad for hashing passwords. Because they are fast by nature means that hashed passwords can be cracked using brute force attacks very easily.

#### Bcrypt to the rescue! 

Ok, why? well, it has built in slowness. [Bcrypt](http://en.wikipedia.org/wiki/Bcrypt) has a built in work factor which gives you the possibility to determine how expensive the hash function has to be. This means that you can make the hashing function slower while computers gets faster.

On my Macbook Air, it takes 25 ms to hash the password 'secret123' 100 times using MD5. When I hash the same password 100 times using Bcrypt it takes 10075 ms. This means that it takes approximately 100 ms to hash a password using BCrypt. That's not much overhead for your login feature but it will be a nightmare for a potential attacker to use brute force to crack your passwords if they get hold of a database dump.

If 100 ms is too much for you, you can always tweak the algorithm and find a good balance between speed and security that fit your needs.

#### This is how you use Bcrypt in Play2:

Add a dependency in build.sbt for jbcrypt:
{% highlight scala %}
name := "bcryptsample"

version := "1.0-SNAPSHOT"

libraryDependencies ++= Seq(
  javaJdbc,
  javaEbean,
  cache,
  "org.mindrot" % "jbcrypt" % "0.3m"
)

play.Project.playJavaSettings
{% endhighlight %}

Run `play update` to update your project dependencies

Sample code for a User model:

{% highlight java %}
package models;

import javax.persistence.*;
import org.mindrot.jbcrypt.BCrypt;
import play.data.validation.Constraints.Required;
import play.db.ebean.Model;

@Entity
public class User extends Model {
  
  @Id
  public Long id;
  
  @Required
  @Column(unique=true)
  public String userName;
   
  public String passwordHash;

  public static Finder<Long, User> find = new Finder(Long.class, User.class);
  
  public static User create(String userName, String password) {
    User user = new User();
    user.userName = userName;
    user.passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());
    user.save();
    return user;
  }
  
  public static User authenticate(String userName, String password) {
    User user = User.find.where().eq("userName", userName).findUnique();
    if (user != null && BCrypt.checkpw(password, user.passwordHash)) {
      return user;
    } else {
      return null;
    }
  }
{% endhighlight %}

#### tl;dr
Use Bcrypt to hash your passwords.