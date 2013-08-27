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

To begin with you need to install JRuby on your system. I'm using [rbenv](https://github.com/sstephenson/rbenv) to manage different Ruby implementations. I won't going in to the details on how to get JRuby running on your system. Just search on Google if you don't know how to setup JRuby.

When you have a running JRuby implementation on your system you can install two gems that we need:

{% highlight bash %}
gem install cmis
gem install rika
{% endhighlight %}

The [CMIS gem](https://github.com/ricn/cmis) is a CMIS client for JRuby. This gem uses the [Apache Chemistry OpenCMIS Java libraries](http://chemistry.apache.org/java/opencmis.html) under the hood.
