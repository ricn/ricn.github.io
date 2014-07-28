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

Unlike Angular and Ember there is not much new lingo to learn when using React.

*Components*

In React, components are the central building blocks of your application.
Components are self-contained, modular, dynamic representations of HTML in your application.
Components are often children of other React components. We will illustrate this later in this tutorial.

Each React component has two types of inputs. The first one is properties (called props) and they are immutable.
The second input is state which is mutable. When we change the state, React will automatically re-render the component
so we can see the changes in the UI. All React components must implement a render methond, which returns another React object or null.

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

*JSX*
As you see in the example above, the render function 

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

  def create
    respond_with :api, :v1, Comment.create(comment_params)
  end

  private

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

When you look at the json output you'll see that it has a root element for comments. To get rid of it we can create an initializer:
{% highlight ruby %}
# config/initializers/active_model_serializer.rb
ActiveModel::Serializer.root = false
ActiveModel::ArraySerializer.root = false
{% endhighlight %}

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
