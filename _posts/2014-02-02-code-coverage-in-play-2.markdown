---
layout: post
title: "Code coverage in Play 2" 
date:   2014-02-02 20:00:00
categories: play2 jacoco
---
<p class="lead">
	How to add code coverage in Play 2 using Jacoco
</p>

Code Coverage measures how many lines/blocks of your code are executed while the automated tests are running.
Code coverage analysis is a powerful tool for finding more of the bugs that most likely do exist in your software – whether you are aware of them or not. As such, a code coverage analysis tool can help you find more programming errors, which enables you to release a software product of better quality.

In this article I'm going to show how to setup this in [Play 2](http://http://www.playframework.com) using [Jacoco](http://www.eclemma.org/jacoco/) which is a Java code coverage library.

#### Setup
Start by creating a new Play 2 application:
{% highlight bash %}

play new codecoverage

{% endhighlight %}

Then choose to create a simple Java application.

After this you need to edit your `plugins.sbt` file.

project/plugins.sbt: 
{% highlight scala %}
// Comment to get more information during initialization
logLevel := Level.Warn

// The Typesafe repository
resolvers += "Typesafe repository" at "http://repo.typesafe.com/typesafe/releases/"

// Use the Play sbt plugin for Play projects
addSbtPlugin("com.typesafe.play" % "sbt-plugin" % "2.2.1")

addSbtPlugin("de.johoop" % "jacoco4sbt" % "2.1.4")
{% endhighlight %}

At the end you see that the Jacoco sbt plugin has been added.

Then you need to configure the Jacoco plugin so it fits in Play 2. Create a file called `qa.jacoco.sbt` in the root folder of your project:
{% highlight scala %}
import de.johoop.jacoco4sbt._

import JacocoPlugin._

jacoco.settings

parallelExecution      in jacoco.Config := false

jacoco.outputDirectory in jacoco.Config := file("target/jacoco")

jacoco.reportFormats   in jacoco.Config := Seq(HTMLReport("utf-8"))

jacoco.excludes        in jacoco.Config := Seq("views*", "*Routes*", "controllers*routes*", "controllers*Reverse*", "controllers*javascript*", "controller*ref*")

{% endhighlight %}

Now we have all the configuration in place so you can now start the play console and run code coverage analysis in your project:

{% highlight bash %}
play
[codecoverage] $ jacoco:cover
{% endhighlight %}

When the jacoco command completes you can open your code coverage report generated under target/jacoco/html/index.html.

You should see something similar to this:

<img src="/images/jacoco.png" />

##### Versions used in this article:
Play 2.2.1

jacoco2sbt 2.1.4

Java 1.7.0_51