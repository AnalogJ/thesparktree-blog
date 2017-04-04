---
layout: post
title: Reusing SailsJS + Waterline Models in Background Tasks
date: '2014-12-09T15:09:00-08:00'
cover: 'assets/images/cover_sails.jpg'
subclass: 'post tag-fiction'
tags:
- sailsjs
- waterline
- nodejs
- kue
redirect_from: /post/104779353989/reusing-sailsjs-waterline-models-in-background
disqus_id: 'http://blog.thesparktree.com/post/104779353989'
categories: 'analogj'
navigation: True
logo: 'assets/logo.png'
---
Its been a while since I first attempted to design a background tasks/workers pattern for my SailsJS app that would let me reuse my well defined models. After posting my first attempt:[Ducktyping SailsJS Core for Background Tasks via Kue](http://blog.thesparktree.com/post/92465942639/ducktyping-sailsjs-core-for-background-tasks-via), I was introduced to a under-documented but more idiomatic feature that I could use to do the same thing: Sails Hooks.

# Background Tasks Requirements

Before diving into the code, let me list some of the requirements I had for my background tasks engine:

- Long running tasks - support for task that may take a significant amount of time to execute.
- Background tasks - can't block the current request/response and wait for the task to finish.
- Easily Generated - tasks must be simple to generate manually (via a CLI, script or the node REPL)
- Simple Integration - task engine shouldn't require any low-level customization of the SailsJS engine
- Leverage SailsJS Models + PubSub - should allow me to reuse all the models, services and features as needed Sails (such as PubSub)

The last two requirements are the most important and most difficult. I wanted to leverage all the power of SailsJS models, while still removing the bloat of a webserver that my background tasks didn't need, and still making sure that I could easily upgrade my SailsJS version.

# Kue

I decided to build my background tasks on top of the incredible Kue library. Kue is a simple priority job queue backed by redis. A basic background processor might look like this:

```javascript
var kue = require('kue')
	, jobs = kue.createQueue({
		prefix: 'kue',
		redis: {
			port: ..,
			host: ..,
			auth: ..
		}
	});

jobs.process("MyBackgroundTaskName",function (job, done) {
	//long running background task goes here.
})


process.once('SIGTERM', function (sig) {
	jobs.shutdown(function (err) {
		console.log('Kue is shut down.', err || '');
		process.exit(0);
	}, 5000);
});
```

I like Kue because its simple and lets me reuse my Redis server (which I use for SailsJS Sessions + PubSub). The background task system I built isn't tied to Kue in any way, you could use any other messaging queue, ActiveMQ, RabbitMQ or whatever.

# Sails Hooks

The Sails.org website has very little to say about the hooks system, but after doing a little digging in the Github project we find this little nugget:

> Sails uses hooks to provide most of it's core functionality. Sails has a hook for it's http server, pubsub functionality, interfacing with an ORM (waterline by default), managing Grunt tasks, etc. Sails even uses a hook for loading your custom hooks. It's called userhooks and it runs after the http server but before the logger. It's one of the last things that happens as you lift your app.

And even a bit of documentation on how to design your own [custom SailsJS Hook](https://github.com/balderdashy/sails-docs/blob/8fc2694a795bc753277f9b970b835dbb384ebfbe/concepts/extending-sails/Hooks/customhooks.md)

There's also a bit of additional documentation about the [Hook API purpose](https://github.com/balderdashy/sails-docs/blob/master/concepts/extending-sails/Hooks/Hooks.md)

As of Dec 2014, here's what we need if we want to run a minimal SailsJS server, without all those webserver features.

```javascript
require('sails').load({
	hooks: {
		blueprints: false,
		controllers: false,
		cors: false,
		csrf: false,
		grunt: false,
		http: false,
		i18n: false,
		logger: false,
		//orm: leave default hook
		policies: false,
		pubsub: false,
		request: false,
		responses: false,
		//services: leave default hook,
		session: false,
		sockets: false,
		views: false
	}
}, function(err, app){

	//You can access all your SailsJS Models and Services here
	User.findOne(1).then(function(user){
		console.log(user)
	})
})
```

Heres a full list of all the [default hooks](https://github.com/balderdashy/sails/blob/master/lib/app/configuration/defaultHooks.js) that can be enabled/disabled in this manner. Note that hooks have dependencies, so you may have to look in the code to figure out exactly whats going on.

# PubSub

At this point we have a minimal working application. However one of the greatest things about Sails is its built in support for websockets, making adding realtime/"comet" features a breeze. Unfortunately the default [pubsub hook](https://github.com/balderdashy/sails/blob/master/lib/hooks/pubsub) depends on the [sockets hook](https://github.com/balderdashy/sails/tree/master/lib/hooks/sockets), which depends on the [http hook](https://github.com/balderdashy/sails/tree/master/lib/hooks/http) which starts up the webserver.

I want my background tasks to work exactly as they would in my Sails apps, and that includes the realtime notification features. Luckily SailsJS is opensource and hooks can be overridden. Long story short, I wrote a modified version of the pubsub hook that can push pubsub notifications to a redis queue, just as the standard pubsub hook does. [AnalogJ/pubsub-emitter on Github](https://github.com/AnalogJ/pubsub-emitter)

Now our simple looks like:

```javascript
require('sails').load({
	hooks: {
		blueprints: false,
		controllers: false,
		cors: false,
		csrf: false,
		grunt: false,
		http: false,
		i18n: false,
		logger: false,
		//orm: leave default hook
		policies: false,
		pubsub: require('pubsub-emitter'),
		request: false,
		responses: false,
		//services: leave default hook,
		session: false,
		sockets: false,
		views: false
	}
}, function(err, app){
	//The SailsJS app is ready

	//You can access all your SailsJS Models and Services here
	User.findOne(1).then(function(user){
		console.log(user)
	})
})
```

#Integrate Kue with Minimal SailsJS App

At this point we have a minimal SailsJS environment and a Kue script, all we have left to do is integrate them together.

I like to create my job definitions in a subfolder and dynamically load them into Kue, this way the only thing I need to do to add a new job is create a new file. Theres no hard coded filenames.

```javascript
// jobs/testJob.js

module.exports = function (job, done) {
	//long running job code here.
	//SailsJS Models and Services are also available here.

	User.findOne({id: job.data.user_id})
	.then(function(){
		//do some processing.

		//call done() when complete (look at the kue docs for more infomation)
	})
	.then(done,done)

}
```

Lets create a simple config file so that our web and worker apps always share the same kue configuration.

```javascript
// config/kue.js

var kue = require('kue')
	, kue_engine = kue.createQueue({
		prefix: 'kue',
		redis: {
			port: 'REDIS_CONNECTION:PORT',
			host: 'REDIS_CONNECTION:HOST',
			auth: 'REDIS_CONNECTION:AUTH'
		}
	});


process.once('SIGTERM', function (sig) {
	kue_engine.shutdown(function (err) {
		console.log('Kue is shut down.', err || '');
		process.exit(0);
	}, 5000);
});

module.exports.kue = kue_engine;
```

To load the Job definition files dynamically we just need to add a small snippet of code after the SailsJS app is ready

```javascript
// worker.js

var _ = require('lodash'),
kue = require('kue'),
q = require('q');

require('sails').load({
	hooks: {
		blueprints: false,
		controllers: false,
		cors: false,
		csrf: false,
		grunt: false,
		http: false,
		i18n: false,
		logger: false,
		policies: false,
		pubsub: require('pubsub-emitter'),
		request: false,
		responses: false,
		session: false,
		sockets: false,
		views: false
	}
}, function(err, app) {

	sails.log.info("Starting kue")
	var kue_engine = sails.config.kue;

	//register kue.
	sails.log.info("Registering jobs")
	var jobs = require('include-all')({
		dirname     :  __dirname +'/jobs',
		filter      :  /(.+)\.js$/,
		excludeDirs :  /^\.(git|svn)$/,
		optional    :  true
	});

	_.forEach(jobs, function(job, name){
		sails.log.info("Registering kue handler: "+name)
		kue_engine.process(name, job);
	})

	kue_engine.on('job complete', function(id) {
		sails.log.info("Removing completed job: "+id);
		kue.Job.get(id, function(err, job) {
			job.remove();
		});
	});

	process.once('SIGTERM', function (sig) {
		kue_engine.shutdown(function (err) {
			console.log('Kue is shut down.', err || '');
			process.exit(0);
		}, 5000);
	});

});
```

And thats all it takes. With these three files we now have a working Background Tasks system that lets us reuse our SailsJS Models/Services, works with PubSub and doesn't require any changes to core SailsJS code.