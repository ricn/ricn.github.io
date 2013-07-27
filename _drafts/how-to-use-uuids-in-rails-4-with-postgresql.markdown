---
layout: post
title: "Use UUIDs in Rails 4 with PostgreSQL"
date:   2013-07-27 21:00:00
categories: rails postgresql
---
<p class="lead">
	How and and why you should use UUIDs as Primary keys in Rails 4 with PostgreSQL
</p>

##### What are UUIDs anyway and why should I use them?

UUID stands for Universally Unique Identifier and the original purpose of UUIDs was to enable distributed systems to uniquely identify objects without significant central coordination. Anyone can create a UUIDs and use them to identify something with reasonable confidence that the same identifier will never be unintentionally created by anyone to identify some other kind of object. 

Objects created with UUIDs can therefore be later combined into a single database without needing to resolve identifier conflicts. 

Another advantage has to do with the randomness of those UUIDs. By not having your UUIDs follow any pattern, it's impossible for potential attackers to be able to go through your database records without you giving them a list of primary UUIDs. Of course, this doesn't automatically make your application secure, but it reduces the damage that is likely to be done if a security bug is exploited.

