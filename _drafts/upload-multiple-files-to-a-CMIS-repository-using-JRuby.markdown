---
layout: post
title: "Upload files to a CMIS repository with JRuby"
date:   2013-08-28 16:00:00
categories: jruby cmis
---
<p class="lead">
	How to upload multiple files to a CMIS repository using JRuby
</p>

[Jeff Potts](http://ecmarchitect.com) recently posted an [article](http://ecmarchitect.com/archives/2013/08/26/3528) that showcases how you can upload multiple files to a CMIS repository using Java. I thought it would be a nice idea to write a similar article but using JRuby instead.

#### What is CMIS?

CMIS stands for Content Management Interoperability Services and it's basically a standardized API that let's you perform CRUD functions against a CMIS compliant server. More information about the [specification](https://www.oasis-open.org/committees/tc_home.php?wg_abbrev=cmis) can be found [here](https://www.oasis-open.org/committees/tc_home.php?wg_abbrev=cmis). Jeff Potts recently wrote a really good [article](http://ecmarchitect.com/archives/2013/08/20/3515) that introduces CMIS.

Here are a few CMIS-compliant content repositories:

* [Alfresco](http://www.alfresco.com/)
* [Nuxeo](http://www.nuxeo.com/)
* [EMC Documentum](http://www.emc.com/domains/documentum/index.htm)
* [Sharepoint](http://sharepoint.microsoft.com/en-us/Pages/default.aspx)
* [IBM FileNet Content Manager](http://www-01.ibm.com/software/data/content-management/filenet-content-manager/)
* [KnowledgeTree](https://www.knowledgetree.com/)

#### What you need

First off, you need to install a CMIS repository on your system. In this article I'm going to use Alfresco 4.2.c Community Edition. Instructions on how to download and install Alfresco can be found [here](http://wiki.alfresco.com/wiki/Download_and_Install_Alfresco)

To begin with you need to install JRuby on your system. I'm using [rbenv](https://github.com/sstephenson/rbenv) to manage different Ruby implementations. I won't go in to the details on how to get JRuby running on your system. Just search on Google if you don't know how to setup JRuby.

When you have a running JRuby implementation on your system you can install two gems that we need:

{% highlight bash %}
gem install cmis
gem install rika
{% endhighlight %}

The [CMIS gem](https://github.com/ricn/cmis) is a CMIS client for JRuby. This gem uses the [Apache Chemistry OpenCMIS Java libraries](http://chemistry.apache.org/java/opencmis.html) under the hood.

The [Rika gem](https://github.com/ricn/rika) is a thin JRuby wrapper for [Apache Tika](http://tika.apache.org/) to extract content and metadata from various file formats.

I'm the author of both gems so if they don't work as expected for you, blame me :-)

#### Create a session
The first thing you need to do is to create a session:

{% highlight ruby %}
require 'cmis'
require 'rika'

atom_url = "http://localhost:8080/alfresco/cmisatom"
user = "admin"
password = "admin"
@session = CMIS::create_session(atom_url, user, password)
{% endhighlight %}

As you can see, creating a session is very simple and straightforward. You only have to specify a username, password and the URL to the CMIS endpoint. CMIS does support both Atom Pub binding and Web Services binding. However, the JRuby gem only supports the Atom Pub binding which is faster than the SOAP Web Services binding and usually it's a better choice. SOAP just sucks anyway so I wont bother implementing support for it in the CMIS gem.

Most CMIS servers only provides one repository by default that you can connect to and the code above automatically connects to the first repository that it finds. This is different behavior compared to the OpenCMIS library where your need to specify a repository explicitly all the time you want to connect. I've chosen to implement this behavior to make it a little bit more convienient to work with the library. However you can specify a different repository if you want to in JRuby. You can read about it in the documentation for the CMIS gem.

#### Get the Target Folder
So now we got a session to work with. CMIS repositories is represented as a hierarchical tree of object consisting of folders and documents just lika a local file system. The example below gets the root folder of the repository and creates a new folder called `Images` in the root folder. We also stores a reference (image_folder) to the new folder so we can use it later:

{% highlight ruby %}
root = @session.root_folder
image_folder = root.create_cmis_folder("Images")
{% endhighlight %}