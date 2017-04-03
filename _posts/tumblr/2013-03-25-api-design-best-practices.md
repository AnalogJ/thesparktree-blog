---
layout: post
title: API Design Best Practices
date: '2013-03-25T00:00:00-07:00'
cover: 'assets/images/cover_code.jpg'
subclass: 'post tag-fiction'
tags:
- GoodReads
- Best Practices
- Architecture
- OAuth
- API
tumblr_url: http://blog.thesparktree.com/post/41988581166/api-design-best-practices
categories: 'analogj'
navigation: True
logo: 'assets/logo.png'

---
Or how to stop third party developers from hating you.

As web developers most of us are accustomed to using APIs. Most of the time all we do is use libraries that abstract away the pain of working with someone elses code, and let us build our products on top.

While working on our cloud ebook manager [QuietThyme](http://www.quietthyme.com), we recognized that integrating GoodReads bookshelves, reviews and comments with our users library would be a very useful feature. We immediately began delving into the GoodReads documentation to check if they had a C# library available for us to use. Unfortunately they didn't and we began the process of creating our own open source implementation.

This post is a summary of some of the pain points that we experienced while implementing a client for the GoodReads API. These issues are definitely not unique to GoodReads, many of the most popular APIs out there have similar issues. I decided to create this post to show API designers that they are creating a `contract` between themselves and their developers. By following the guidelines below they can insure that the process of implementing their API is as simple as possible.

# 1. Every API should return a consistent wrapper object

Developers need to know the status of every API response. API designers need to choose a consistent way of returning state information, either by always returning the status via the HTTP headers or, the more preferred way, by creating a wrapper that includes status information as well as the API return data.

GoodReads seems to do this by returning a Request tag inside most API responses:

```xml
<goodreadsresponse><request><authentication>true</authentication><key></key><method></method></request>
  **API RESPONSE DATA HERE**
<goodreadsresponse>
```

However it soon becomes apparent that when an error occurs they instead just return:

    <error>book not found</error>

or :

    Invalid Request

or even an empty xml document, which throws the following error in most XML parsers:

    This page contains the following errors:
    error on line 1 at column 1: Document is empty


This is not acceptable. By mixing response xml data structures, you force developers to write multiple response handlers, and then run them all until a 'valid' response is found. Its even worse when plain text is returned when XML is assumed.

Instead if they had returned something like this:

```xml
<goodreadsresponse><request><authentication>true</authentication><key></key><method></method><errorcode>4321</errorcode><error>book not found</error></request>
  **API RESPONSE DATA HERE**
<goodreadsresponse>
```

The developer would only have to check if the errorcode field has a value, or is greater than 0, and if so display the error message, otherwise the response is known to be correct and only **one** response handler is required. The integration is much more stable and testable.

# 2. Support multiple formats, or don't

Every developer has a preference for output formats, some love JSON, some love XML. API designers understand that, and for the most part they leverage the serialization support built into most modern frameworks to output both formats. However as developers we understand that for each output format you decide to support, time will need to be taken to test and ensure all your data is serialized properly. We even understand if most of your APIs support both, but a few only support one or the other. However please **do not** decide to mix it up and have some your API support one format, some the other, and some both. It's inconsistent and painful to implement. Every deserialization implementation has its own quirks, which takes time.

```
URL: http://www.goodreads.com/book/title?format=FORMAT
HTTP method: GET
Parameters:
format: xml or json
..

URL: http://www.goodreads.com/author/list.xml
HTTP method: GET
Parameters:
key: Developer key (required).
..

URL: http://www.goodreads.com/book/review_counts.json
HTTP method: GET
Parameters:
format: json
..
```

If you can't support the same formats on all methods of your API, please pick at least one format and make sure it can be returned by all API calls.

# 3. Support API versioning

Again, it's about consistency in your API. It gives you, the API designer the freedom to deprecate methods in newer versions of your API while still giving developers using your old API time to restructure their code.

Somewhat related to versioning is an issue I noticed with the following GoodReads API:

```
Get the Goodreads book ID given an ISBN. Response contains the ID without any markup.
URL: http://www.goodreads.com/book/isbn_to_id
HTTP method: GET
Parameters:
key: Developer key (required).
isbn: The ISBN of the book to lookup.
```

When called upon by my C# library, the GoodReads api will instead return the result for:

```
Get the reviews for a book given an ISBN
Get an xml or json file that contains embed code for the iframe reviews widget that shows excerpts (first 300 characters) of the most popular reviews of a book for a given ISBN. The reviews are from all known editions of the book.
URL: http://www.goodreads.com/book/isbn?format=FORMAT&amp;isbn=ISBN
```

I can only assume that either GoodReads has deprecated the `isbn_to_id` API without any notice, or they have some sort of API routing error such that isbn_to_id == isbn

# 4. Keep your response key types consistent.
When returning unique identifiers such a book ids or comment ids, tweet ids or anything else, it helps if the key type is consistent across different API calls.

If your book id is an integer then this response if fine from one api:


```xml
<bookid type="integer">1001</bookid>
```

or even this from another:

```
<bookid>1001</bookid>
```

But please, never have another API return this:

```
<bookid type="string">1001</bookid>
```

# 5a. Keep your API parameter handling consistent.
If you have multiple related APIs that all take in the same parameter, such as `name`, for different CRUD operations, ensure that the parameter is handled the same way across the group.

For example, if your `name` parameter is case-insensitive for the Create, Update and Delete APIs, make sure it is also case insensitive for the Read API. We noticed that the GoodReads `Edit book shelf` and `Get the books on a members shelf` API calls both took a bookshelf name as a parameter, but when requesting the `Get the books on a members shelf` API, the bookshelf name is case sensitive, even though the `Edit book shelf` and other bookshelf related calls are case insensitive.

# 5b. Keep your API parameter count consistent.
If we see this in your developer documentation, something has gone horribly wrong:

```
Get the reviews for a book given an ISBN
Get an xml or json file that contains embed code for the iframe reviews widget that shows excerpts (first 300 characters) of the most popular reviews of a book for a given ISBN. The reviews are from all known editions of the book.
URL: http://www.goodreads.com/book/isbn?format=FORMAT&amp;isbn=ISBN
HTTP method: GET
Parameters:
format: xml or json
callback: function to wrap JSON response if format=json
**key: Developer key (required only for XML).**
**user_id: 8488829 (required only for JSON)**
...
```
The number of parameters to use your api should be the same if its JSON or XML, the only exception being if your output is JSONP and you need a callback parameter.

# 6. The API url matters.
Its only a minor issue, but it does make a difference. Structure your API into logical groups if possible. It helps us break up our API client along the same lines. As well, having a consistent base url makes it just a little bit easier to use your API. Something along the lines of:

    http://www.MyAwesomeSAAS.com/api/{Group}/{Action}

is just a bit nicer to work with than:

```
http://www.goodreads.com/user_shelves.xml
http://www.goodreads.com/list/book.xml?id=BOOK_ID
http://www.goodreads.com/api/auth_user
http://www.goodreads.com/api/author_url/<id>
```

# 7. Use OAuth
Or atleast some sort of API authentication. Yes it is a bit of an investment, yes you will need to spend time and money implementing it and yes, it might break YAGNI. The problem is that if you're going to build an API, you want developers using it, you want it to become popular. And if you wait until your API does become popular to implement OAUTH, you are creating a significant breaking change that's going to force all the developers using your API to restructure their code. Use OAuth in your API, follow the spec. We're comfortable using OAuth libraries, and if your API works with it out of the box, then we can jump right into implemeting your API.

# 8. API documentation
APIs take hours to design and develop. You will be spending enormous amounts of effort to make your API as developer friendly as possible. You should be putting the same effort into your developer documentation. As the designer of a popular API you may feel like you're spending a huge portion of your day telling developers to RTFM, and thats never going to disappear. But if you do it right, for every developer that gets lazy and skips the documentation, you'll have 10 that were able to integrate your API without any problems.


# Summary
I didn't mean to make GoodReads the API whipping boy here, we've all had to deal with API integration problems before, but with the growing prevalence of SAAS, I thought you should see some of the issues that developers are facing when using your API.

[QuietThyme](http://www.quietthyme.com)
GoodReads integration is just one of the many third-party services we support at [QuietThyme](http://www.quietthyme.com). We support the usual Facebook, Twitter, LinkedIn and Google authentication as well as allowing you to store you full library on your own private DropBox while letting us manage your Ebook Metadata and Cover art. Check us out at www.quietthyme.com.

