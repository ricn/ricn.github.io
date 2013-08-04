---
layout: post
title: "Full text search for attachments with Rails and Elasticsearch"
date:   2013-08-05 18:00:00
categories: rails elasticsearch
---

<p class="lead">
  How to add full text search for attachments with Rails and Elasticsearch
</p>

Many web apps provides some sort of full text search for the content in the application. Many of them also allow users to upload and share files. However, most of them just index the metadata of the content and don't care about the actual content in the uploaded files. This can be frustrating for a user who uses your search feature and searches for a word they know exists in a file but they get no result.

In this article I'm going to show you how you can implement this kind of feature in Rails using [Elasticsearch](http://www.elasticsearch.org/).

#### What is Elasticsearch?

Elasticsearch is a distributed open source search server based on Apache Lucene. It allows for real-time searching and the ability to scale easily through replicas. Getting started is easy as elasticsearch is schema less. You only have to pass it a typed JSON document and it will automatically be indexed for you. Types are automatically determined by the server. It also allows you to define your own mappings to set boost levels, analyzers, and types.

#### Install Elasticsearch

It's easy to install Elasticsearch on a mac using Homebrew:

{% highlight bash %}
brew install elasticsearch
{% endhighlight %}

Notice the instructions that Homebrew shows you on how to start / stop Elasticsearch.

If you're using another operating system or if you don't use Homebrew you can follow the instructions [here](http://www.elasticsearch.org/guide/reference/setup/installation/) to install Elasticsearch.

#### The attachment type plugin
In order to be able to index the actual content of files in Elasticsearch we need to install [The attachment type plugin](http://www.elasticsearch.org/guide/reference/mapping/attachment-type/). This plugin allows us to index different attachment type field (encoded as base64), for example, Microsoft Office formats, PDFs, open document formats, ePub, HTML, and so on. The full list of supported file formats can be found [here](http://tika.apache.org/1.4/formats.html).

This is how you install the plugin:
{% highlight bash %}
cd /usr/local/opt/elasticsearch # If you did not use Homebrew the installation path might differ.
bin/plugin -install elasticsearch/elasticsearch-mapper-attachments/1.7.0
# restart Elasticsearch
{% endhighlight %}

#### Setup Rails
{% highlight bash %}
rails new elasticsearch --skip-bundle

# Edit Gemfile
gem 'tire'
gem 'carrierwave'

bundle install
{% endhighlight %}

The [Tire gem](https://github.com/karmi/tire) exposes an easy to use domain specific language to communicate with Elasticsearch. It integrates easily with your ActiveModel/ActiveRecord classes for convenient usage in your Rails app.

The [Carrierwave gem](https://github.com/carrierwaveuploader/carrierwave) is used to upload files from your Rails app.

#### Create the ActiveRecord model
{% highlight ruby %}
rails generate model document title:string document_attachment:string
rake db:migrate

# this should give you this file app/uploaders/document_attachment_uploader.rb:
rails generate uploader DocumentAttachment
{% endhighlight %}

This will give us one Document model and an uploader called DocumentAttachment.

The uploader should look something like this:
{% highlight ruby %}
# app/uploaders/document_attachment_uploader.rb
class DocumentAttachmentUploader < CarrierWave::Uploader::Base
  storage :file
  
  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end
end
{% endhighlight %}

We can leave the DocumentAttachment class as is. This version will store files directly on disk but Carrierwave also support Amazon S3 and other cloud services if you want to use that instead.

Now is the time to setup the uploader and integrate our Document model with Elasticsearch:
{% highlight ruby %}
class Document < ActiveRecord::Base
  # We're mounting the uploader the document_attachment attribute.
  # This attribute will store the path to the attachment.
  mount_uploader :document_attachment, DocumentAttachmentUploader
	
  # Setting up ElasticSearch integration
  include Tire::Model::Search
  include Tire::Model::Callbacks
	
  mapping _source: { excludes: ['attachment'] } do
    indexes :id, type: 'integer'
    indexes :title
    indexes :attachment, type: 'attachment'
  end

  def attachment
    path_to_attachment = document_attachment.file.file
    Base64.encode64(open(path_to_attachment) { |file| file.read })
  end

  def to_indexed_json
    to_json(methods: [:attachment])
  end
end
{% endhighlight %}

The first thing we do in the model is to mount the uploader with the document_attachment attribute. After that we include Tire to make the integration with ElasticSearch work. After that we setup a mapping block which describes what and how we should index and store our data in ElasticSearch. Note that we exclude that attachment in the beginning of the block. We do this because we don't want to store the actual content of the file in the index because that will make your index grow very fast. However, this doesn't mean the content won't be indexed. The other lines in the block just specifices what we want to index and what type they should be. The attachment type is not available in ElasticSearch by default but we got it by installing the attachment type plugin.

Next we have defined a attachment method. ElastichSearch requires that we send the file content as a Base64 encoded string so the method fixes that. After that we have specified a method that returns the actual json that will be posted to ElasticSearch and we have specified that the result of the attachment method should be included.