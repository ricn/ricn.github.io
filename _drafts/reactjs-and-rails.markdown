---
layout: post
title: "React and Rails"
date:   2014-07-28 08:00:00
categories: rails react
---
<p class="lead">
  How to use React in your Rails projects
</p>

#### Introduction

#### React theory

Unlike Angular and Ember their is not much new lingo to learn.

React objects are called components. Each of them may contain data and renders view in a declarative way - based only on current data state.

Each React component has 2 inputs:

props - shortcut of properties, these are mean to be immutable
state - mutable

After changing the state, React will automatically re-render the component to answer a new input.

In addition, all React components must implement render method, which must return another React object or null (from version 0.11).

#### Setup the Rails API

We need a Rails API for React frontend to communicate with in order to store and retrieve comments.

{% highlight bash %}
rails new react-demo
{% endhighlight %}

First we need to add the following to our Gemfile:

gem 'active_model_serializers'
gem 'ffaker'

And you should also remove

Run bundle install to install your gems.

ActiveModel::Serializers encapsulates the JSON serialization of objects. Objects that respond to
read_attribute_for_serialization (including ActiveModel and ActiveRecord objects) are supported. A serializer
will automatically be created when we use the Rails generator to generate the comment resource.

The ffaker gem will be used to create some sample data for our application.

Next, we need to create our resource:

{% highlight bash %}
rails g resource comment comment:text author:string
{% endhighlight %}

Because we are using the active_model_serializers gem, a serializer will automatically
be generated for us:

{% highlight ruby %}
  # app/serializers/comment_serializer.rb
  class CommentSerializer < ActiveModel::Serializer
    attributes :id, :comment, :author
  end
{% endhighlight %}

Now that we have our resource and serializer, we can create the API controller.

First we need routes for the API controller. Add them to the top of your Rails router:

{% highlight ruby %}
  # config/routes.rb
  namespace :api do
    namespace :v1 do
      resources :comments
    end
  end
{% endhighlight %}

Now we can create the comments api controller. The actions here are pretty standard:

{% highlight ruby %}
  # app/controllers/api/v1/comments_controller.rb
  class Api::V1::CommentsController < ApplicationController
    respond_to :json

    def index
      respond_with Comment.all
    end

    def show
      respond_with comment
    end

    def create
      respond_with :api, :v1, Comment.create(comment_params)
    end

    def update
      respond_with comment.update(comment_params)
    end

    def destroy
      respond_with lead.destroy
    end

    private

    def comment
      Comment.find(params[:id])
    end

    def comment_params
      params.require(:comment).permit(:author, :comment)
    end
  end
{% endhighlight %}

You should also remove the comments controller that were generated in app/controllers because we won't use that one.

We can now create some sample data to test our new Rails API:

Create a new rake task:

{% highlight ruby %}
  # lib/tasks/populate.rake
  namespace :db do
    task populate: :environment do

      Comment.destroy_all

      10.times do
        Comment.create(
          author: Faker::Name.first_name + " " + Faker::Name.last_name,
          comment: Faker::HipsterIpsum.words(10).join(' ')
          )
      end
    end
  end
{% endhighlight %}

Now run:
rake db:migrate
rake db:populate

Restart the server, and now you should be able to visit:
[http://localhost:3000/api/v1/comments.json](http://localhost:3000/api/v1/comments.json) and see the JSON output for all comments.
[http://localhost:3000/api/v1/comments/1.json](http://localhost:3000/api/v1/comments/1.json) should show you the first comment.

Now we have a fully functional Rails API that we can use in in the tutorial.

#### Setup React in Rails

For this tutorial we are going to use the react-rails gem which installs the required
js-files needed.

Open your Gemfile and add the following:

gem 'react-rails'

Run bundle install

This will install the latest stable release of the react-rails gem.

Next, we need to create a home controller which we will wire to the root url:

{% highlight bash %}
rails g controller home index
{% endhighlight %}

Then open up your routes.rb file and add this:

{% highlight ruby %}
root 'home#index'
{% endhighlight %}

After this we can replace the index view content for our home controller with the following content:

{% highlight erb %}
# app/views/home/index.html.erb
<h1>Comments</h1>
<div id="content"></div>
{% endhighlight %}

The content div will be used as a starting point where we will render the stuff from React
