---
layout: post
title: "Better password hashing in Play 2.2"
date:   2013-10-22 08:00:00
categories: playframework bcrypt
---

#### Why not just use good ol' MD5, SHA1 or SHA256?
These are all general purpose hash functions, designed to calculate a digest of huge amounts of data in as short a time as possible. This means that they are fantastic for ensuring the integrity of data and utterly rubbish for storing passwords.

A modern server can calculate the MD5 hash of about 330MB every second. If your users have passwords which are lowercase, alphanumeric, and 6 characters long, you can try every single possible password of that size in around 40 seconds.

#### Bcrypt to the rescue! 

How? Basically, it’s slow as hell. It uses a variant of the Blowfish encryption algorithm’s keying schedule, and introduces a work factor, which allows you to determine how expensive the hash function will be. Because of this, bcrypt can keep up with Moore’s law. As computers get faster you can increase the work factor and the hash will get slower.

How much slower is bcrypt than, say, MD5? Depends on the work factor. Using a work factor of 12, bcrypt hashes the password yaaa in about 0.3 seconds on my laptop. MD5, on the other hand, takes less than a microsecond.

So we’re talking about 5 or so orders of magnitude. Instead of cracking a password every 40 seconds, I’d be cracking them every 12 years or so. Your passwords might not need that kind of security and you might need a faster comparison algorithm, but bcrypt allows you to choose your balance of speed and security. Use it.

build.sbt:
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