---
layout: post
title: Creating a Sails Application using Passport Authentication
date: '2014-02-20T16:58:00-08:00'
cover: '/assets/images/cover_sails.jpg'
subclass: 'post tag-post'
tags:
- nodejs
- sailsjs
- passportjs
- sails
redirect_from:
- /post/77311774912/creating-a-sails-application-using-passport
- /post/77311774912
disqus_id: 'http://blog.thesparktree.com/post/77311774912'
categories: 'analogj'
navigation: True
logo: '/assets/logo.png'

---

# Creating a Sails Application using Passport Authentication

1. `$ mkdir sails-passport-authentication`

2. `$ sails new .`

3. `$ sails generate user`

4. Populate the `User` model

		/api/models/User.js

		module.exports = {

		  attributes: {
		      firstName: {
		          type: 'string'
		      },
		      lastName: {
		          type: 'string'
		      },
		      email: {
		          type: 'email'
		      },
		      provider: {
		          type: 'string'
		      },
			  provider_id:{
			  	  type: 'string'
              },
		      password: {
		          type: 'string'
		      }
		  }

		};

5. Create the `passport-local` login view

		/views/user/login.ejs

		<form action="/user/login" method="post">
			<div>
				<label>Email:</label>
				<input type="text" name="email"><br></div>
			<div>
				<label>Password:</label>
				<input type="password" name="password"></div>
			<div>
				<input type="submit" value="Submit"></div>
		</form>

	At this point we could run `$ sails lift` and access the `passport-local` login page by visiting [http://localhost:1337/user/login](http://localhost:1337/user/login)

6. Create a test user

	Visit [http://localhost:1337/user/create?email=test@test.com&password=12345](http://localhost:1337/user/create?email=test@test.com&password=12345) in a browser to create a new user with a username of `test@test.com` and a password of `12345`

# Enabling `passport` with local authentication requires a few steps:

1. `$ npm install passport --save`

2. `$ npm install passport-local --save`

3. Creating the passport middleware configuration file.

		/config/passport.js

		var passport = require('passport'),
		LocalStrategy = require('passport-local').Strategy;

		passport.serializeUser(function(user, done) {
			done(null, user.id);
		});

		passport.deserializeUser(function(id, done) {
			User.findOneById(id).done(function (err, user) {
				done(err, user);
			});
		});

		passport.use(new LocalStrategy({
        		usernameField: 'email',
        		passwordField: 'password'
    		},
			function(email, password, done) {
		    User.findOne({ email: email}).done(function(err, user) {
		  		  if (err) { return done(err); }
		  			if (!user) { return done(null, false, { message: 'Unknown user ' + email }); }
		  			if (user.password != password) { return done(null, false, { message: 'Invalid password' }); }
		  			return done(null, user);
		  		});
		  	}
		));

4. Register the required passport connect middleware

		/config/express.js

		var passport = require('passport');

		module.exports.express = {
			customMiddleware: function (app) {
				app.use(passport.initialize());
				app.use(passport.session());
			}
		};

5. Create the UserController actions

		/api/controllers/UserController.js

		var passport = require('passport');
		module.exports = {
		    login: function (req,res)
		    {
		        res.view();
		    },

		    passport_local: function(req, res)
		    {
		        passport.authenticate('local', function(err, user, info)
		        {
		            if ((err) || (!user))
		            {
		                res.redirect('/user/login');
		                return;
		            }

		            req.logIn(user, function(err)
		            {
		                if (err)
		                {
		                    res.redirect('/user/login');
		                    return;
		                }

		                res.redirect('/');
		                return;
		            });
		        })(req, res);
		    },

		    logout: function (req,res)
		    {
		        req.logout();
		        res.redirect('/');
		    },



		  /**
		   * Overrides for the settings in `config/controllers.js`
		   * (specific to UserController)
		   */
		  _config: {}


		};

6. Modify routes to handle post to `/user/login`.

		/config/routes.js

		module.exports.routes = {
		    '/': {
		        view: 'home/index'
		    },
		    'get /user/login':{
		        controller: 'user',
		        action: 'login'
		    },
		    'post /user/login':{
		        controller: 'user',
		        action: 'passport_local'
		    }
		}

7. Create policy file
	This policy file will check that the user has been authenticated by `Passport` and if not it will redirect them to the login page.

		/api/policies/isAuthenticated.js

        module.exports = function(req, res, next) {

            // User is allowed, proceed to the next policy,
            // or if this is the last policy, the controller
            // Sockets
            if(req.isSocket)
            {
                if(req.session &&
                    req.session.passport &&
                    req.session.passport.user)
                {
                    //Use this:

                    // Initialize Passport
                    sails.config.passport.initialize()(req, res, function () {
                        // Use the built-in sessions
                        sails.config.passport.session()(req, res, function () {
                            // Make the user available throughout the frontend
                            //res.locals.user = req.user;
                            //the user should be deserialized by passport now;
                            next();
                        });
                    });

                    //Or this if you dont care about deserializing the user:
                    //req.user = req.session.passport.user;
                    //return next();

                }
                else{
                    res.json(401);
                }


            }
            else if (req.isAuthenticated()) {
                return next();
            }
            else{
                // User is not allowed
                // (default res.forbidden() behavior can be overridden in `config/403.js`)
                return res.redirect('/account/login');
            }
        };

8. Apply policy file
	The following configuration requires all requests to be authenticated. The only exception is requests to the user controller.

		/config/policies.js

		module.exports.policies = {
		    '*': 'isAuthenticated',
		    'user': {
		        '*': true
		    }
		}

	Running `$ sails lift` and attempting to access any controller other than `user` will redirect you to the `/user/login`.

	Note:
	Policies only apply to controllers, not views. Which means that the root '/' index view will still be accessible until you put it behind a controller. [https://github.com/balderdashy/sails/issues/1132](https://github.com/balderdashy/sails/issues/1132)


Now test your application by running `$ sails lift` then visiting `http://localhost:1337/user/login`.
Just login with the email and password for the user we created initially:

- email: test@test.com
- password: 12345

You should now be redirected to the homepage.