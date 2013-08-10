---
layout: post
title: "Add Syntax highlighting to the cat command for Rubyists"
date:   2013-08-11 00:00:00
categories: ruby shell
---

I use the cat command in the terminal every single day to take a peek at source code. When you look at source code in terminal you probably want it to be syntax highlighted. In this article I'm going to show how you can do it using the excellent [coderay](https://github.com/rubychan/coderay).

This is how I did on my Mac:

{% highlight bash %}
gem install coderay
rbenv rehash

echo 'alias cat="coderay"' >> ~/.bashrc
source ~/.bashrc

cat my_source_file.rb
{% endhighlight%}

This is how it will look in the terminal when using coderay:

<img src="/images/coderay.png" />

