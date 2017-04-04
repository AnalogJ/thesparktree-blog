---
layout: post
title: API Design Best Practices - Part 2
date: '2014-03-20T10:01:00-07:00'
cover: 'assets/images/cover_code.jpg'
subclass: 'post tag-fiction'
tags:
- API
redirect_from: /post/80164111992/api-design-best-practices-part-2
disqus_id: 'http://blog.thesparktree.com/post/80164111992'
categories: 'analogj'
navigation: True
logo: 'assets/logo.png'
---
This is a follow up to my previous API design post ["API Design Best Practices"](http://blog.thesparktree.com/post/41988581166/api-design-best-practices)

# Use the new hotness

Use the newest standards whenever possible, rather than an older standard that you're more comfortable with. In general older standards have fewer maintained libraries, making it harder for developers to start integrating with your API. Standards change over time for a variety of reasons, be it security or feature set. Unless you have a specific use case for using an old standard, choose the newest one.
The official OAuth ruby gem is a good example of the pain developers go though trying to find maintained libraries for old standards. The official OAuth link for the ruby gem is the github repo: `pelle/oauth` which informs you to go to the newer version on `mojodna/oauth` which then tells you to visit `oauth/oauth-ruby` which does not exist. The correct library is `oauth-xx/oauth-ruby`, last updated 2 years ago,


# Don't be bleeding edge

Remember, draft specifications expire. If your going to use a spec that has still not been ratified, make sure you keep it up to date, even once you finish your API.  As the specification is finalized, developers attempting to use popular libraries will run into uncommon and hard to debug issues with your no-longer-standard API. Highrise designed their API to support OAuth2 when it was still in the process of being ratified, creating an API supporting [draft version 2.07](http://tools.ietf.org/html/draft-ietf-oauth-v2-07). They use an option `web_server` that has since been removed in the finalized specification, almost 24 releases later.


# XML is evil

That headline is more link-bait than anything, but there is a reason that you see fewer and fewer XML based API's. Partially because JSON is the new hotness (with the community support that entails), but also because XML is verbose, heavier and harder to code. JSON was designed from the ground up to serialize data structures, while XML was designed to give semantic definition to text in documents.

It's easy to understand how the following JSON structure maps to a data structure

```json
{
	"name": "Jason Kulatunga",
	"email": "Jason@TheSparkTree.com",
	"website": "http://www.thesparktree.com"
}
```

However it's XML equivalent can be written in many different ways.

```xml
<person><name>Jason Kulatunga</name><email>Jason@TheSparkTree.com</email><website>http://www.thesparktree.com</website></person>
```

or

```xml
<person name="Jason Kulatunga" email="Jason@TheSparkTree.com" website="http://www.thesparktree.com"></person>
```

This makes it just that much harder to generate XML requests, or parse XML responses into data structures. The [Freshbooks Invoices API](http://developers.freshbooks.com/docs/invoices/) provides a example of why requests formats are standardized to `application/json` or `applicaton/www-form-encoded`.


# Responses shouldn't lie

If you're implementing a specification that has a standardized response format, please don't decide to send a response with a different encoding. Sending a correct `Content-Type` header is not enough, a deviation means you are no longer complaint with the specification.
Facebook is guilty of this. The OAuth2 specification states that upon successful OAuth authentication:

	The parameters are included in the entity-body of the HTTP response using the "application/json" media type

However they decided to ignore this, and instead return a `www-form-encoded` response, meaning that most standard OAuth2 libraries will be unable to parse the access token correctly.


# Never design your own serialization format

You should never see the following in the documentation as a sample response for any API.

```
#Wed Feb 29 03:07:33 PST 2012
AUTHTOKEN=bad18eba1ff45jk7858b8ae88a77fa30
RESULT=TRUE
```

The above is an example of [ZOHO](http://www.zoho.com/crm/help/api/using-authentication-token.html)'s serialization format for passing back tokens after successful authentication. It's confusing, follows no encoding standards (even the date is a custom format) and mixes the way data is structured (the expiry timestamp is a comment??).
Response formats are standardized, do not make your own, even XML is better than this. This should never have happened.


# SOAP is dead

Like XML, SOAP API's are talked about with disdain for a reason. Please don't use SOAP if you're building a new API -I'm looking at you Paypal.

# Support untrusted third-parties

ZOHO is my punching bag again for this example, but I've seen many SAAS's do the same thing. Here's the scenario: you want to access an API on behalf of a user, but to access the endpoints you need an API key. So far so good. Now to generate the API key, you need the user's username and password which you send to a special API, that returns an API key. Wait what? First of all you're forcing your users to give their usernames and passwords to third parties just so the third party can access their data. As an API designer your also limiting your control and knowledge over how your API is being used as you can no longer track popular/abusive applications. Never make the developer request the user's username and password to generate an API key, it makes the OAuth process completely redundant.

# Per Application rate limits are evil

We as developers understand that you need to place limits on our applications so we do not abuse your system, but sane request limits are preferred. API requests/user/day{other time period} are preferred rather than a API request limit per application. Per application rate limits only abuse your most successful developers. Per user rate limits allow our applications to grow at a reasonable rate. The Twitter API fiasco is a good example of how per application rate limits can hurt your most devoted developers.

# Provide developer test data accounts.

You have a paid product, something that your clients use, love and are willing to pay for monthly. You also have an API, and you want to make it easy for developers to integrate with your ecosystem and provide additional value for using your service. If these statements are true, please do not expect us to build a meaningful application within your trial period. We are users too, and we hate having to create throw away accounts for development. Provide us with permanent test accounts, preferably ones that are filled out with reasonable test data.

# Scope permissions

Creating an application with granular security is hard and complicated, but scaring the user into thinking that we will have access to view and change their private data on your service when all we want to do is read their name and email address is a huge blow to trustworthiness. Please build support for granular permissions if it makes sense.

# Offline Application Access

Inline with the previous point about Scope, you want to protect your users from shady Developers, so you decide that your API access tokens are going to expire after 30 minutes...Here's looking at you XERO. Please don't do that, provide us with a offline access scope and a refresh token, make it obvious to the user that we will be accessing their data even when they are not logged in, and show them that they can remove access to our application at anytime.

#Please don't mix and match API authentication/validation schemes.

Paymill makes third party developers use OAuth2 to authenticate as a user, after which point we have to use the newly requested accesstoken as a username with basic authentication..wat?

# Custom url endpoints per customer

So you're a company that wants to provide your users with branded url. Something like: `myawesomecompany.lessaccounting.com` or `beeniebabysrus.uservoice.com`. Even if that's the way that the users can access their data, please do not force us as developers to visit `myawesomecompany.lessaccounting.com/oauth/authenticate` to start your OAuth flow. It just means that I'm forced to ask the user what their company url is before they can even login. Once they login, you will have their domain anyways, and you can associate it with their accesstoken.

# Consistent names in documentation

Please use the standard nomenclature for OAuth if you are using it: `client_id`, `customer key`, `client_secret`, `consumer secret`. Don't use `APIkey`, `api token key`, `api secret key`, `api key secret`, `some other made-up name here`. We're developers, we understand technical documentation and we prefer nomenclature that matches the variables and parameters that we have been using on every other site that talks about OAuth. Please don't confuse us with your own naming structures.

# Consistent documentation

Keep your documentation consistent. If you have a product, that you call Paymill Connect, and then later on you create a new product called Paymill Unite that incorporates the features of Connect and extends them, please remove your outdated documentation, or make it obvious that it has been superseded by Unite. Also if you're going to show one of the token endpoints on a "Getting Started" page, show the other one too. It's frustrating when people stop in the middle without

# Documentation is King

The number of developers that integrate their application with your service is directly proportional to the difficulty in finding and understanding your documentation. Anyone who's ever attempted to understand the Paypal Classic API using their documentation site will understand what I mean.

Salesforce is an example of a large, correctly documented API. Stripe's level of documentation should be the goal for most small to medium size API's.

[http://www.salesforce.com/us/developer/docs/api_rest/](http://www.salesforce.com/us/developer/docs/api_rest/)

# Show total counts when paginating results
Stripe has a great API, but even they could make a few small changes that would make the lives of developers easier. If you are paginating responses, please provide us with a total count, instead of just a response count. I'm not saying this would be as easy as it sounds, as I understand that depending on your database you may have to do a full count query to get this number. Its just a nice to have as a developer.


# Encoding Body parameters

URL encoding body individual body parameters.... why would you do this? And if you are going to do it, be consistent. Encode the whole body not parts of it. [https://gist.github.com/IntuitDeveloperRelations/6024616#file-v2-qbo-item-filter-v2sdk-devdefined-cs-L19](https://gist.github.com/IntuitDeveloperRelations/6024616#file-v2-qbo-item-filter-v2sdk-devdefined-cs-L19)

# Hashing algorithms

If you are going to use a hash of the parameters as a signature in your API, make sure you also explicitly state how the hash is generated, the algorithm and the order of the parameters. Distimo is at fault here.

# Provide a REST API

Braintree doesn't have a public REST API, instead they just provide gems and libraries in various languages for integration. While giving them kudos for wrapping their API in over 8 different languages, sometimes its nice to have direct access to an API for testing with Postman, Fiddler, curl, etc.