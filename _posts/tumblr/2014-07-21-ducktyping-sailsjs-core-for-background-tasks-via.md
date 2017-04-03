---
layout: post
title: Ducktyping SailsJS Core for Background Tasks via Kue
date: '2014-07-21T17:32:00-07:00'
cover: 'assets/images/cover_sails.jpg'
subclass: 'post tag-fiction'
tags:
- kue
- nodejs
- javascript
- sailsjs
tumblr_url: http://blog.thesparktree.com/post/92465942639/ducktyping-sailsjs-core-for-background-tasks-via
categories: 'analogj'
navigation: True
---

# Update
After this post was written I was introduced to Sails Hooks, which is a built-in but under-documented feature of SailsJS, which allows you to configure the SailsJS engine. I've written a new post about how to create background tasks in Sails which you can find here:

[Reusing SailsJS + Waterline Models in Background Tasks](http://blog.thesparktree.com/post/104779353989/reusing-sailsjs-waterline-models-in-background)


I recently found myself with a common problem: my application needed to do some long running tasks, and I didn't to block the current request/response and wait for them to finish. My application is built ontop of the SailsJS library which meant that I could use one of the many express.js libraries that add support for background tasks.

# Kue

I was able to add support for the incredibly useful [Kue](https://github.com/learnboost/kue) library by adding 2 simple files to the config folder.

## Kue Job Definitions

```javascript
/app/config/kue.js

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
	User.findOne(job.data.user_id)
		.then(function (user) {
			return user.long_running_background_task()
		})
		.then(function (processed) {
			console.log("finished job!");
			console.log(processed);
			done();
		})
		.fail(function (err) {
			console.log("error in job!");
			console.log(err);
			done(err);
		})
		.done();
})


process.once('SIGTERM', function (sig) {
	jobs.shutdown(function (err) {
		console.log('Kue is shut down.', err || '');
		process.exit(0);
	}, 5000);
});
module.exports.jobs = jobs;
```

##ExpressJS Middleware

```javascript
/app/config/express.js

module.exports.express = {
	customMiddleware: function (app) {
		// This should be password protected on your app.

		app.use('/tools/queue', require('kue').app);
	}
}
```

And with those two additions, everything worked great, for a time.

# Component based architecture

The problem I had with my application, and more importantly with Sails, is that the background jobs are tied very closely with the way that Sails worked under the hood. Sails uses a convention based system, similar to Rails, to load up the Models, Controllers, Services and Views. Any changes to my background jobs, which heavily used instance methods in my Models, would require a redeploy of the full application. My log files and error messages were all intertwined as well. My dream of running my background jobs in CoreOS/docker style containers, scalable on demand seemed almost impossible with Sails's convention based magic.

I started looking into the way that Sails worked under the covers, and I realized that I could duck-type the Sails environment for a standalone application, allowing me to reuse all my Models and Services, without having to run a full Sails web server for my background tasks.

Note: As always, the full working code can be accessed on a gist [here](https://gist.github.com/AnalogJ/bbec266c6d85dc2d215f#file-sails_ducktyping_for_background_tasks-js)

## Global `sails` object and required configuration

As this is a simple prototype I just used the `global` object to define `sails`.

```javascript
///////////////////////////////////////////////////
// SAILS ENV
///////////////////////////////////////////////////
//resolve the required sails config files.
var config_path = path.resolve(__dirname,'../..', 'config/')
global.sails = {
	config: {}
};

//custom configuration file I use
sails.config.constants = require(config_path+'/constants.js').constants;
sails.log = require(config_path+'/log.js').log.custom
```

## Registering Services

Registering the services was simple. I just needed to require and attach them to the global object

```javascript
///////////////////////////////////////////////////
// WATERLINE SERVICES
///////////////////////////////////////////////////
var api_dir = path.resolve(__dirname,'../..', 'api/')

// load services
var services = require('include-all')({
	dirname     :  api_dir +'/services',
	filter      :  /(.+)\.js$/,
	excludeDirs :  /^\.(git|svn)$/,
	optional    :  true
});

_.forEach(services, function(service,key){
	sails.log.info("Loading service: "+key)
	global[key] = service;
});
```

## sails.models and Waterline

Reusing the models incredibly simple as well. I just used Waterline which Sails uses under the covers. My application uses the PostgreSQL Waterline adapter, but you can use any that Waterline supports --MongoDB, Redis, MySQL, ...

```javascript
///////////////////////////////////////////////////
// WATERLINE CONFIG
///////////////////////////////////////////////////
var orm = new Waterline();
// Require any waterline adapters here
var postgresqlAdapter = require('sails-postgresql');


// Build A Config Object
var config = {

	// Setup Adapters
	// Creates named adapters that have have been required in models
	adapters: {
		'sails-postgresql': postgresqlAdapter
	},

	// Build Connections Config
	// Setup connections using the named adapter configs
	connections: {
		qtPostgresqlServer: {
			adapter: 'sails-postgresql',
			host: ...,
			port: ...,
			user: ...,
			password: ...,
			database: connection.path.substring(1)
		}
	},

	defaults: {
		migrate: 'alter'
	}

};


///////////////////////////////////////////////////
// WATERLINE MODELS
///////////////////////////////////////////////////
var api_dir = path.resolve(__dirname,'../..', 'api/')

// load models
var models = require('include-all')({
	dirname     :  api_dir +'/models',
	filter      :  /(.+)\.js$/,
	excludeDirs :  /^\.(git|svn)$/,
	optional    :  true
});

_.forEach(models, function(model,key){
	sails.log.info("Register model: "+key)
	model.identity = key.toLowerCase();
	model.connection = 'qtPostgresqlServer';

	..snip.. // additional socket publish methods go here. Check the Sails sockets section for more info.

	var waterline_model = Waterline.Collection.extend(model);
	orm.loadCollection(waterline_model);
});

///////////////////////////////////////////////////
// WATERLINE INIT
///////////////////////////////////////////////////
function init_waterline(){
	var deferred = q.defer();
	// Start Waterline passing adapters in
	orm.initialize(config, function(err, models) {
		if (err) {
			return deferred.reject(err)
		}
		else{
			sails.log.info("Waterline ready")

			return deferred.resolve(models);
		}
	});

	return deferred.promise;
}

///////////////////////////////////////////////////
// STANDALONE APP IN SAILS-LIKE ENV
///////////////////////////////////////////////////

init_waterline().then(function(waterline_models){
		sails.models = waterline_models.collections;
		sails.connections = waterline_models.connections;

		//register Waterline Models globally by name ie, User.findOne, Item.where()
		_.forEach(sails.models, function(model, name){
			name = name.charAt(0).toUpperCase() + name.slice(1);
			global[name] = model;
		})

		//test function
		User.find().then(function(users){
			console.log("SUCCESS!", users);
			})

	})
```

## Sails Sockets (Advanced)

At this point we have a working sails-like app. My configuration is loaded, my models are accessible via Waterline and they have access to the Sails object and my services.

But wait, what about the Sails pub-sub functionality? One of the greatest features of Sails is its simple and easy to use socket system. Out of the box it can simply update the front-end when a Model event occurs (update, create, delete, etc). Now that we're doing the model processing outside of Sails, how do we notify Sails and the front-end of model events?

Sails is a production-focused framework, with out of the box support for horizontal scaling via Redis. As long as we publish events to Redis in the same format as Sails does, our socket functionality will be completely transparent.

I initially attempted to do this part via the [socket.io-emitter](https://github.com/Automattic/socket.io-emitter/) library, but I wasn't able to successfully publish Sails compatible events.

Going down to the raw Redis library was the solution.

```javascript
///////////////////////////////////////////////////
// REDIS CONFIG
///////////////////////////////////////////////////
global.redis_client = redis.createClient({{REDIS_PORT}}, {{REDIS_HOST}});

function init_redis(){
	var deferred = q.defer();
	redis_client.on("ready", function () {
		sails.log.info("Redis ready")
		return deferred.resolve(redis_client);
	});

	return deferred.promise;
}

function generate_model_message(model_name,model_id,action, verb,data){
	var message = {
		"name":model_name,
		"args":[{
			"verb" : verb,
			"data" : data.toJSON(),
			"id" : model_id
		}]
	};
	var wrapper = {};
	wrapper.nodeId = 648745922; //this could be randomly chosen if we cant determine the client id.
	wrapper.args = [
			"/sails_model_"+model_name+"_"+model_id + ":"+action,
			"5:::"+JSON.stringify(message),
		null,
		[]
	]
	return JSON.stringify(wrapper);
}


function generate_association_message(model_name,model_id,attribute, id_associated, action, verb, verbId){
	var item ={
		"verb" : verb,
		"attribute" : attribute,
		"id" : model_id
	}
	item[verbId] = id_associated;


	var message = {
		"name":model_name,
		"args":[item]
	};

	var wrapper = {};
	wrapper.nodeId = 648745922; //this could be randomly chosen if we cant determine the client id.
	wrapper.args = [
			"/sails_model_"+model_name+"_"+model_id + ":"+action+":"+attribute,
			"5:::"+JSON.stringify(message),
		null,
		[]
	]
	return JSON.stringify(wrapper);
}
```

The two generate methods above help help us create socket Redis messages in a format that Sails understands. They are prototype methods right now, and may require some additional tweaking over time to fully mimic the Sails socket message structure.

I then had to add the missing `publishCreate`, `publishRemove`, `publishAdd`, `publishUpdate` socket helpers to the Waterline models.

```javascript
_.forEach(models, function(model,key){
	sails.log.info("Register model: "+key)
	model.identity = key.toLowerCase();
	model.connection = 'qtPostgresqlServer';

	//add publish methods
	model.publishCreate = function(id, data){
		redis_client.publish("dispatch", generate_model_message(model.identity,id,"update","updated",data))
	};
	model.publishUpdate = function(id, data){
		redis_client.publish("dispatch", generate_model_message(model.identity,id,"create","created",data))
	};
	model.publishAdd = function(id,attribute, idAdded){
		redis_client.publish("dispatch", generate_association_message(model.identity,id,attribute, idAdded, "add", "addedTo", "addedId"))
	};
	model.publishRemove = function(id,attribute, idRemoved){
		redis_client.publish("dispatch", generate_association_message(model.identity,id,attribute, idRemoved, "remove", "removedFrom", "removedId"))
	};

	..etc..


	var waterline_model = Waterline.Collection.extend(model);
	orm.loadCollection(waterline_model);
});
```

Now when we call the publish* methods in our background tasks/standalone application, it will publish socket messages just as Sails would.

## Kue Engine
The whole reason I started this was to process background tasks outside of Sails, so lets add Kue into our app.
The main runloop now looks like:

```javascript
q.spread([init_redis(),init_waterline()],function(redis_client,waterline_models){
	sails.models = waterline_models.collections;
	sails.connections = waterline_models.connections;

	_.forEach(sails.models, function(model, name){
		name = name.charAt(0).toUpperCase() + name.slice(1);
		global[name] = model;
	})

	sails.log.info("Starting kue")
	var kue_engine = kue.createQueue({
		prefix: 'kue',
		redis: {
			port: ...,
			host: ...
		}
	});

	//register jobs (located in seperate files)
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

	process.once('SIGTERM', function (sig) {
		kue_engine.shutdown(function (err) {
			sails.log.error("Shutting down kue")
			process.exit(0);
		}, 5000);
	});
});
```

# Fin

Now you should be able to run your application completely outside of Sails, as long as you have the required models, services and config files. You can even mount it into a docker container, like I do.
As I said, the final gist can be found [here](https://gist.github.com/AnalogJ/bbec266c6d85dc2d215f#file-sails_ducktyping_for_background_tasks-js). The code is MIT licensed so feel free to hack it apart.