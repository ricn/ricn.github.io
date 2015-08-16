---
layout: post
title: "Build a RESTful API using Dropwizard and PostgreSQL"
date:   2014-11-10 17:00:00
categories: dropwizard postgresql java
---
<p class="lead">
  How to build a RESTful API using Dropwizard and PostgreSQL.
</p>

[Dropwizard](http://dropwizard.io/) is starting to become my first choice when developing RESTful APIs.
[Dropwizard](http://dropwizard.io/) is a framework which pulls together stable and mature Java libraries and package your whole application into a single runnable jar file. All you need to run a [Dropwizard](http://dropwizard.io/) application is Java, your jar file and a yaml config file. No complex application required!

[Dropwizard](http://dropwizard.io/) has built in support for configuration, application metrics, logging, operational tools, and much more, allowing you and you to ship a production-quality web service in the shortest time possible.

#### What we are going to build

1. Handle CRUD for an item. We're going to use cats.

2. Have a standard URLs like http://example.com/api/cats and http://example.com/api/cats/:catId. Dropwizard uses [Jetty](http://www.eclipse.org/jetty/) for HTTP

3. Use the proper HTTP like GET, POST, PUT, DELETE verbs to make it RESTful. Dropwizard uses [Jersey](https://jersey.java.net/) for REST

4. Return JSON data. Dropwizard uses [Jackson](http://wiki.fasterxml.com/JacksonHome) for JSON

5. Persist cats to a PostgreSQL database. We're going to use JDBI and Liquibase to handle all the stuff around the database.

#### What we need before getting started
 1. Java 7 or 8

 2. Maven

 3. PostgreSQL

 4. An IDE like Intellij, Eclipse or Netbeans

#### Setup
Create a new maven project in your favorite IDE and add the following dependencies to your pom.xml:

{% highlight bash %}
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>io.rny.dropwizard</groupId>
  <artifactId>dw-pg-demo</artifactId>
  <version>1.0-SNAPSHOT</version>

  <properties>
    <dropwizard.version>0.7.1</dropwizard.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>io.dropwizard</groupId>
      <artifactId>dropwizard-core</artifactId>
      <version>${dropwizard.version}</version>
    </dependency>

    <dependency>
      <groupId>io.dropwizard</groupId>
      <artifactId>dropwizard-jdbi</artifactId>
      <version>${dropwizard.version}</version>
    </dependency>

    <dependency>
      <groupId>io.dropwizard</groupId>
      <artifactId>dropwizard-migrations</artifactId>
      <version>${dropwizard.version}</version>
    </dependency>

  </dependencies>
</project>
{% endhighlight %}

Write something about dropwizard-core, dropwizard-jdbi & dropwizard-migrations
