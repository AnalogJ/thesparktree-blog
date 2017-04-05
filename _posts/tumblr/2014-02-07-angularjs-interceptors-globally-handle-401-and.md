---
layout: post
title: AngularJS Interceptors - Globally handle 401 and other Error Messages
date: '2014-02-07T20:50:53-08:00'
cover: '/assets/images/cover_angularjs.png'
subclass: 'post tag-post'
tags:
- angularjs
- javascript
- nodejs
redirect_from:
- /post/75952317665/angularjs-interceptors-globally-handle-401-and
- /post/75952317665
disqus_id: 'http://blog.thesparktree.com/post/75952317665'
categories: 'analogj'
navigation: True
logo: '/assets/logo.png'

---

If you've built your slick new app using AngluarJS you're probably using the common pattern of using AngluarJS as your dynamic client side MVVM framework and delegating your server side code to act as a API for the most part.

Traditional server side web frameworks had it easy. If you detected that your user is unauthenticated and is attempting to access a restricted resource your framework would easily handle that by automatically redirecting the user to a login page.

Unfortunately this pattern doesn't hold up well when building a Single-Page-Application (SPA) using a client side framework and leaving the server side as a simple json API. Since client side frameworks can't authenticate the user directly for security reasons, there may be times where a user attempts to access an API without knowing that they are unauthorized, or that their session has expired.


In the following guide I'll explain how to configure an AngularJS Single Page Application to handle `401 Unauthorized` and Authenticated requests in a standard way.

# Technology Stack

Before getting started you should note that this guide was written and tested with a NodeJS server API, however that does not mean it won’t work with your configuration. YMMV.

- AngularJS `v1.2.x`
- NodeJS `v0.10.x`
- ExpressJS `v3.x`
- Passport `v0.2.0`

# NodeJS API + Passport Authentication

Protecting API endpoints with Passport is easy. All we need to do is specify a middleware function to handle any endpoints that need to be protected.

```javascript
app.all('/api/member/:member_id',requiresAuth, function(req, res){
	//do authenticated magic here.
	return res.json({member: member_data});
})

function requiresAuth (req, res, next) {
	if (req.isAuthenticated()) return next();
	res.statusCode = 401;
	var json_resp = {};
	if (req.method == 'GET') json_resp.returnTo = req.originalUrl
	res.json(json_resp)
}
```

The `requiresAuth` function returns a 401 error code if the user is not authenticated, which we can then handle in AngularJS via an Interceptor.

# AngularJS Interceptor

The following AngularJS Interceptor can be used to globally handle any 401 error, and handle them by redirecting the user to the `/login` page.

```javascript
angular.module('myApp', ['ngRoute']).
config(['$routeProvider', '$locationProvider', function($routeProvider,$locationProvider) {
	$routeProvider.when('/', {templateUrl: '/angular/public/index', controller: 'indexCtrl'});
	$routeProvider.when('/login', {templateUrl: '/angular/public/login', controller: 'loginCtrl'});
	$routeProvider.when('/members', {templateUrl: '/angular/member/index', controller: 'memberIndexCtrl'});
	//... snipped


	$routeProvider.otherwise({redirectTo: '/'});
	$locationProvider.html5Mode(true);
 }])
.factory('authHttpResponseInterceptor',['$q','$location',function($q,$location){
	return {
		response: function(response){
			if (response.status === 401) {
				console.log("Response 401");
			}
			return response || $q.when(response);
		},
		responseError: function(rejection) {
			if (rejection.status === 401) {
				console.log("Response Error 401",rejection);
				$location.path('/login').search('returnTo', $location.path());
			}
			return $q.reject(rejection);
		}
	}
}])
.config(['$httpProvider',function($httpProvider) {
	//Http Intercpetor to check auth failures for xhr requests
	$httpProvider.interceptors.push('authHttpResponseInterceptor');
}]);
```

The previous snippet only handled the 401 error code but you could use the same premise to handle other 4xx and 5xx Error Codes.