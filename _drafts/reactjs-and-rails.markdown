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
# app/controllers/comments_controller.rb
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

{% highlight ruby %}
rake db:migrate
rake db:populate
rails server
{% endhighlight %}

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

For this tutorial we are going to use [the react-rails gem](https://github.com/reactjs/react-rails) which installs the required
js-files needed.

Open your Gemfile and add the following:

{% highlight ruby %}
gem 'react-rails'
{% endhighlight %}

Run `bundle install`

Then we need to add react to `application.js`:

{% highlight javascript %}
// app/assets/javascripts/application.js

//= require react

{% endhighlight %}

Make sure to require react after turbolinks or weird things might happen.

You also need to configure variants to use for different environments.
There are 2 variants available. `:development` gives you the unminified version of React.
This provides extra debugging and error prevention. `:production` gives you the minified version of
React which strips out comments and helpful warnings, and minifies.

{% highlight ruby %}
# config/environments/development.rb
Rails.application.configure do
  config.react.variant = :development
end

# config/environments/production.rb
Rails.application.configure do
  config.react.variant = :production
end
{% endhighlight %}

Next, we need to create a home controller which we will wire to the root url:

{% highlight bash %}
rails g controller home index
{% endhighlight %}

Then open up your `routes.rb` file and add this:

{% highlight ruby %}
# config/routes.rb
root 'home#index'
{% endhighlight %}

After this we can replace the index view content for our home controller with the following content:

{% highlight html %}
# app/views/home/index.html.erb
<div id="comments"></div>
{% endhighlight %}

The comments div will be used as a starting point where we will render the React stuff.

OK, now we should have everything setup to start using React. To prove it we can add
this Hello World example in `comments.js.jsx`:
{% highlight javascript %}
# app/assets/javascripts/comments.js.jsx
/** @jsx React.DOM */
var HelloWorld = React.createClass({
  render: function() {
    return (
      <div className='HelloWorld'>
        Hello, world!
      </div>
      );
  }
});

var ready = function () {
  React.renderComponent(
    <HelloWorld />,
    document.getElementById('comments')
  );
};

$(document).ready(ready);
{% endhighlight %}

When you visit [http://localhost:3000](http://localhost:3000) you should now see `Hello, world!`

#### Implementing the comment component

Now is the time to start implementing the real React components for this tutorial.
As we said earlier React is all about modular and composable component.

The following component structure will be used in this tutorial:

* ###### - CommentBox
  * ###### - CommentList
    * ###### - Comment
  * ###### - CommentForm

We're going to implement the components from inside out so the first one will be the Comment component.
The comment component will be responsible for rendering a single comment with an author and comment text property:

Replace the Hello World example in your `comments.js.jsx` with this:

{% highlight javascript %}
# app/assets/javascripts/comments.js.jsx
/** @jsx React.DOM */
var Comment = React.createClass({
  render: function () {
    return (
      <div className="comment">
        <h2 className="commentAuthor">
          {this.props.author}
        </h2>
          {this.props.comment}
      </div>
      );
  }
});

var ready = function () {
  React.renderComponent(
    <Comment author="Richard" comment="This is a comment "/>,
    document.getElementById('comments')
  );
};

$(document).ready(ready);
{% endhighlight %}

So the only thing that's different here compared to the Hello World component is
that we're passing in hard coded properties that we use in the render method.
By surrounding a JavaScript expression in braces inside JSX , you can drop text or React components into the tree.
We access named attributes passed to the component as keys on this.props.

You can now refresh your the page in your browser and you should see the comment.

#### Implementing the CommentList component

The next component we need to add the CommentList component which will
be responsible for rendering a list of comments:

{% highlight javascript %}
/** @jsx React.DOM */
var Comment = // Removed to save space

var CommentList = React.createClass({
  render: function () {
    var commentNodes = this.props.comments.map(function (comment, index) {
      return (
        <Comment author={comment.author} comment={comment.comment} key={index} />
        );
    });

    return (
      <div className="commentList">
        {commentNodes}
      </div>
      );
  }
});

var ready = function () {
  var fakeComments = [
    { author:"Richard", comment:"This is a comment" },
    { author:"Nils", comment:"This is another comment" }
  ];

  React.renderComponent(
    <CommentList comments={fakeComments} />,
    document.getElementById('comments')
  );
};

$(document).ready(ready);
{% endhighlight %}

OK, let's start from the bottom and take a look at the `React.renderComponent` method.
We're now passing in an array with fake comments to the `CommentList` component.

In the render method in `CommentList` we're using the map function to iterate thru
the array of comments and returning a new array with new Comment component instances.

Then we just renders the comment list and adds the list with comment components.

Refresh the page in the browser and you should now see two hard coded comments.

#### Implement the CommentBox component

Now is the time to add the top level `CommentBox` component. The CommentBox will
be responsible to display the CommentList and the CommentForm (we will implement it later) on the page. It's also
this component that will talk to our backend:

{% highlight javascript %}
/** @jsx React.DOM */
var Comment = // Removed to save space
var CommentList = // Removed to save space

var CommentBox = React.createClass({
  getInitialState: function () {
    return {comments: []};
  },
  componentDidMount: function () {
    this.loadCommentsFromServer();
  },
  loadCommentsFromServer: function () {
    $.ajax({
      url: this.props.url,
      dataType: 'json',
      success: function (comments) {
        this.setState({comments: comments});
      }.bind(this),
      error: function (xhr, status, err) {
        console.error(this.props.url, status, err.toString());
      }.bind(this)
    });
  },
  render: function () {
    return (
      <div className="commentBox">
        <h1>Comments</h1>
        <CommentList comments={this.state.comments} />
      </div>
      );
  }
});

var ready = function () {
  React.renderComponent(
    <CommentBox url="/comments.json" />,
    document.getElementById('comments')
  );
};

$(document).ready(ready);
{% endhighlight %}

As you can see, the CommentBox is a little bit more complicated and contains
more React specific code that we need to explain.

The first thing is the how `state` works. So far, each component has rendered itself once based on its props.
`props` are immutable: they are passed from the parent and are "owned" by the parent.

To implement interactions, we introduce mutable state to the component.
`this.state` is private to the component and can be changed by calling `this.setState()`.
When the state is updated, the component re-renders itself.

The `getInitialState` method is a special method that executes exactly once during the
lifecycle of the component and sets up the initial state of the component. In the CommentBox we
set an empty list with comments.

The next method is `componentDidMount` which is autmatically called by React when the
component is rendered. In this example we only execute the `loadCommentsFromServer`.
This method uses plain old [jQuery](http://jquery.com/) to fetch comments from our API.

When we get a successful response from the server, we change the state of the old comments array with 
a new one from the server by calling `this.setState({comments: comments})`

The UI will automatically updates itself.

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
