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

[React](http://facebook.github.io/react/index.html) is often used as the V in MVC.
Since React makes no assumptions about the rest of your technology stack, it's easy to try it out on a small
feature in an existing project.

React uses a virtual DOM diff implementation for ultra-high performance.
It can also render on the server using Node.js — no heavy browser DOM required.

React implements one-way reactive data flow which reduces boilerplate and is
easier to reason about than traditional data binding.

Unlike [AngularJS](https://angularjs.org/) and [Ember](http://emberjs.com/) there is not a lot of new concepts that you need to learn.

In this tutorial I'm going to show you how to use React in [Rails](http://rubyonrails.org/). It's heavily based on the original
tutorial for React that you can find [here](http://facebook.github.io/react/docs/tutorial.html) but I have added Rails specific parts to it.

###### Components

In React, components are the central building blocks of your application. Components are self-contained, modular,
dynamic representations of HTML in your application. Components are often children of other React components.
We will illustrate this later in this tutorial how that works.

Each React component has two types of inputs. The first one is properties (called props) and they are immutable.
The second input is state which is mutable. When we change the state, React will automatically re-render the component
so we can see the changes in the UI. All React components must implement a render method, which returns another React object.

This is a very simple React component:

{% highlight javascript %}
/** @jsx React.DOM */
var HelloMessage = React.createClass({
  render: function() {
    return <div>Hello {this.props.name}</div>;
  }
});

React.renderComponent(<HelloMessage name="Richard" />, mountNode);

{% endhighlight %}

Here you can see the render method that takes input data and returns what to display.
This example uses an XML-like syntax called [JSX](http://facebook.github.io/react/docs/jsx-in-depth.html). Input data that is passed into the component can be accessed by render() via this.props.
JSX is optional and not required to use React.

*Also notice the comment on the top of the file. It’s required to make the compilation from JSX to plain Javascript to work so it’s very important.*

The JSX compiler will produce the following Javascript:

{% highlight javascript %}
/** @jsx React.DOM */
var HelloMessage = React.createClass({displayName: 'HelloMessage',
  render: function() {
    return React.DOM.div(null, "Hello ", this.props.name);
  }
});

React.renderComponent(HelloMessage({name: "John"}), mountNode);
{% endhighlight %}

#### What we are going to build

As I wrote earlier, this tutorial is going to be heavily based on the tutorial you can find on the React home page.

We'll be building a simple, but realistic comments box that you can drop into a blog, a basic version of the realtime comments offered by Disqus, LiveFyre or Facebook comments.

We'll provide:

1. A view of all of the comments
2. A form to submit a comment
3. A JSON API built with Rails to list and create new comments

It'll also have a few neat features:

Optimistic commenting: comments appear in the list before they're saved on the server so it feels fast.
Live updates: as other users comment we'll pop them into the comment view in real time

#### Setup the Rails API

The first thing we need to do is to setup the Rails backend so our React frontend
can create and list comments from the server.

Start by creating a new Rails project:

{% highlight bash %}
rails new react-demo
{% endhighlight %}

First we need to add the following to our Gemfile:

{% highlight ruby %}
gem 'active_model_serializers'
gem 'ffaker'
{% endhighlight %}

Run `bundle install` to install your gems.

[The active_model_serializers gem](https://github.com/rails-api/active_model_serializers) encapsulates the JSON serialization of objects. Objects that respond to
read_attribute_for_serialization (including ActiveModel and ActiveRecord objects) are supported. A serializer
will automatically be created when we use the Rails generator to generate the comment resource.

[The ffaker gem](https://github.com/EmmanuelOga/ffaker) will be used to create some sample data for our application.

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

Now that we have our comment resource and serializer.

Now we can create the comments api controller. The actions here are pretty standard:

{% highlight ruby %}
# app/controllers/api/v1/comments_controller.rb
class CommentsController < ApplicationController
  respond_to :json

  def index
    respond_with Comment.all
  end

  def create
    respond_with Comment.create(comment_params)
  end

  private

  def comment_params
    params.require(:comment).permit(:author, :comment)
  end
end
{% endhighlight %}

We can now create some sample data to test our new Rails API. Create a new rake task:

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
rails server

Now you can try out your comments API:

[http://localhost:3000/comments.json](http://localhost:3000/comments.json) and see the JSON output for all comments.

When you look at the json output you'll see that it has a root element for comments. To get rid of it we can create an initializer:

{% highlight ruby %}
# config/initializers/active_model_serializer.rb
ActiveModel::Serializer.root = false
ActiveModel::ArraySerializer.root = false
{% endhighlight %}

Restart your server and the root elements will now be gone.

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

{% highlight html %}
# app/views/home/index.html.erb
<h1>Comments</h1>
<div id="content"></div>
{% endhighlight %}

The content div will be used as a starting point where we will render the stuff from React.

#### Create your first React component!

React is all about modular and composable components. The following component structure will be used in this tutorial:

* -- CommentBox
  * -- CommentList
    * -- Comment
  * -- CommentForm

Now is the time to actually add some React specific code to our project

When we generated our comment resource a comments.js file were created in
assets/javascripts/ folder. First we need to rename it to comments.js.jsx. This is
needed to transform your JSX code into JavaScript.

Add the following code:

{% highlight javascript %}
# app/assets/javascripts/comments.js.jsx
/** @jsx React.DOM */
var CommentBox = React.createClass({
  render: function() {
    return (
      <div className='commentBox'>
        Hello, world! I am a CommentBox.
      </div>
    );
  }
});

var ready = function () {
    React.renderComponent(
        <CommentBox />,
        document.getElementById('content')
    );
};

$(document).ready(ready);
{% endhighlight %}

Restart your server and you should see "Hello, world! I am a CommentBox." displayed on your page.

The first thing you'll notice is the XML-ish syntax in your JavaScript.
We have a simple precompiler that translates the syntactic sugar to this plain JavaScript.
Its use is optional but we've found JSX syntax easier to use than plain JavaScript. Read more on the [JSX Syntax article](http://facebook.github.io/react/docs/jsx-in-depth.html).
Also notice the comment on the top of the file. It's required to make the compilation from JSX to plain Javascript to work so it's very important.

*What's going on*

We pass some methods in a JavaScript object to React.createClass() to create a new React component. The most important of these methods is called render which returns a tree of React components that will eventually render to HTML.

The <div> tags are not actual DOM nodes; they are instantiations of React div components. You can think of these as markers or pieces of data that React knows how to handle. React is safe. We are not generating HTML strings so XSS protection is the default.

You do not have to return basic HTML. You can return a tree of components that you (or someone else) built. This is what makes React composable: a key tenet of maintainable frontends.

React.renderComponent() instantiates the root component, starts the framework, and injects the markup into a raw DOM element, provided as the second argument.

#### The CommentBox component
{% highlight javascript %}
var CommentBox = React.createClass({
  loadCommentsFromServer: function () {
    $.ajax({
      url: this.props.url,
      dataType: 'json',
      success: function (data) {
        this.setState({data: data});
      }.bind(this),
      error: function (xhr, status, err) {
        console.error(this.props.url, status, err.toString());
      }.bind(this)
    });
  },
  handleCommentSubmit: function (comment) {
    var comments = this.state.data;
    var newComments = comments.concat([comment]);
    this.setState({data: newComments});
    $.ajax({
      url: this.props.url,
      dataType: 'json',
      type: 'POST',
      data: { "comment": comment },
      success: function (data) {
        this.loadCommentsFromServer();
      }.bind(this),
      error: function (xhr, status, err) {
        console.error(this.props.url, status, err.toString());
      }.bind(this)
    });
  },
  getInitialState: function () {
    return {data: []};
  },
  componentDidMount: function () {
    this.loadCommentsFromServer();
    setInterval(this.loadCommentsFromServer, this.props.pollInterval);
  },
  render: function () {
    return (
      <div className="commentBox">
        <h1>Comments</h1>
        <CommentList data={this.state.data} />
        <CommentForm onCommentSubmit={this.handleCommentSubmit} />
      </div>
    );
  }
});
{% endhighlight %}

#### The comment list component

{% highlight javascript %}
var CommentList = React.createClass({
  render: function () {
    console.log(this.props);
    var commentNodes = this.props.data.map(function (comment, index) {
      return (
        <Comment author={comment.author} key={index}>
          <p>{comment.comment}</p>
        </Comment>
      );
    });

    return (
      <div className="commentList">
        {commentNodes}
      </div>
    );
  }
});
{% endhighlight %}


#### The comment form component

{% highlight javascript %}
var CommentForm = React.createClass({
  handleSubmit: function () {
    var author = this.refs.author.getDOMNode().value.trim();
    var comment = this.refs.comment.getDOMNode().value.trim();
    if (!comment || !author) {
      return false;
    }
    this.props.onCommentSubmit({author: author, comment: comment});
    this.refs.author.getDOMNode().value = '';
    this.refs.comment.getDOMNode().value = '';
    return false;
  },
  render: function () {
    return (
      <form className="commentForm" onSubmit={this.handleSubmit}>
        <input type="text" placeholder="Your name" ref="author"/>
        <input type="text" placeholder="Say something..." ref="comment"/>
        <input type="submit" value="Post" />
      </form>
    );
  }
});
{% endhighlight %}

#### The comment component

{% highlight javascript %}
var Comment = React.createClass({
  render: function () {
    return (
      <div className="comment">
        <h2 className="commentAuthor">
          {this.props.author}
        </h2>
          {this.props.children}
      </div>
      );
  }
});
{% endhighlight %}
