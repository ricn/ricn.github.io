---
layout: post
title: "Use Amazon SQS in Play 2" 
date:   2014-02-10 20:00:00
categories: java play2 amazonsqs
---
<p class="lead">
	How to use Amazon Simple Queue Service in Play 2
</p>

Amazon SQS (Simple Queue Service) is a distributed queue messaging service provided by Amazon. It supports programmatic sending of messages via web service applications as a way to communicate over the Internet. SQS is intended to provide a highly scalable hosted message queue that resolves issues arising from the common producer-consumer problem or connectivity between producer and consumer.

In this article I'm going to show you how to setup and integrate Amazon SQS in [Play 2](http://http://www.playframework.com).

#### Setup Amazon Web Services and SQS
First off you need to sign up at [Amazon Web Services](http://aws.amazon.com) if you don't already have an account.

When you have an account ready and have logged in to [Amazon Web Services](http://aws.amazon.com) you'll see all the services that Amazon offers. Under the App Services section you'll find the SQS. Click on SQS and then click on Create New Queue. Just give your queue a name and save it.

Your new queue gets an unique URL that you need later to connect to the queue. Make sure to write it down:
<img src="/images/sqs.png" />

Also make sure to visit the Security Credentials page and create an Access Key ID and Secret Access Key.

#### Setup Play

Create a new Play 2 project:
{% highlight bash %}

play new sqs

{% endhighlight %}

Then choose to create a simple Java application. After this you need to add [AWS SDK for Java](http://aws.amazon.com/sdkforjava/) to your project.

build.sbt: 
{% highlight scala %}
name := "sqs"

version := "1.0-SNAPSHOT"

libraryDependencies ++= Seq(
  javaJdbc,
  javaEbean,
  cache,
  "com.amazonaws" % "aws-java-sdk" % "1.7.1"
)

play.Project.playJavaSettings
{% endhighlight %}

Now you can run this command to resolve the dependencies:

{% highlight bash %}

play update

{% endhighlight %}

We also need to prepare our application with the necessary configuration needed to connect to Amazon SQS. Add the following configuration to the bottom of your conf/application.conf file:

{% highlight bash %}

## Amazon Credentials
aws.access.key = "ADD-YOUR-ACCESS-KEY-HERE"
aws.secret.key = "ADD-YOUR-SECRET-KEY-HERE"

## Amazon SQS configuration
aws.sqs.url="ADD-YOUR-SQS-QUEUE-URL-HERE"
aws.sqs.setMaxNumberOfMessages=2
{% endhighlight %}

#### Create the SQS Plugin
When I integrate stuff with third party services in Play 2 I like to create a plugin. A Play 2 plugin is a class that extends the Java class play.Plugin. This class may be something you have written in your own application, or it may be a plugin from a module.

Create a new class named `SQSPlugin` and put it under a `plugins` package, and let it extend play.Plugin. There are three methods that we can override – onStart(), onStop() and enabled(). You can also add a constructor that takes a play.Application argument.

To have some functionality occur when the application starts, override onStart(). To have functionality occur when the application stops, override onStop().

Here's my implementation:
{% highlight java %}
package plugins;

import java.util.List;
import play.*;
import com.amazonaws.auth.*;
import com.amazonaws.services.sqs.AmazonSQSClient;
import com.amazonaws.services.sqs.model.*;

public class SQSPlugin extends Plugin {
  public static final String AWS_ACCESS_KEY = "aws.access.key";
  public static final String AWS_SECRET_KEY = "aws.secret.key";
  private final Application application;
  private static AmazonSQSClient client;
    
  public SQSPlugin(Application application) {
    this.application = application;
  }

  public static void sendMessage(String queueUrl, String message) {
    SendMessageRequest sendMsgReq = new SendMessageRequest(queueUrl, message);
    client.sendMessage(sendMsgReq);
  }

  public static List<Message> receiveMessages(String queueUrl, int maxNumberOfMessages) {
    ReceiveMessageRequest receiveMsgReq = new ReceiveMessageRequest(queueUrl);
    receiveMsgReq.setMaxNumberOfMessages(maxNumberOfMessages);
    ReceiveMessageResult result = client.receiveMessage(receiveMsgReq);
    return result.getMessages();
  }

  public static void deleteMessage(String queueUrl, Message msg) {
    DeleteMessageRequest delMsgRequest = new DeleteMessageRequest(queueUrl, msg.getReceiptHandle());
    client.deleteMessage(delMsgRequest);
  }
    
  @Override
  public void onStart() {
    String accessKey = application.configuration().getString(AWS_ACCESS_KEY);
    String secretKey = application.configuration().getString(AWS_SECRET_KEY);
    if ((accessKey != null) && (secretKey != null)) {
       AWSCredentials awsCredentials = new BasicAWSCredentials(accessKey, secretKey);
       client = new AmazonSQSClient(awsCredentials);
    }
  }

  @Override
  public boolean enabled() {
    return (application.configuration().keys().contains(AWS_ACCESS_KEY) &&
      application.configuration().keys().contains(AWS_SECRET_KEY));
  }
}
{% endhighlight %}

So this class gives us some basic functionality to send a message to a specified queue, receive a list of messages so we can do something with them and also a method to delete a message from the queue.

To make the plugin statup when your application starts up you have to create a `play.plugins` file in the conf directory with the following content:

{% highlight bash %}
1501:plugins.SQSPlugin
{% endhighlight %}


##### Versions used in this article:

Play 2.2.1

AWS Java SDK 1.7.1

Java 1.7.0_51