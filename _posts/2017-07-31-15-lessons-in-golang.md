---
layout: post
title: 15 Lessons in Golang
date: '2017-07-31T01:19:33-08:00'
cover: '/assets/images/cover_golang.png'
subclass: 'post tag-post'
tags:
- golang
- capsulecd
- docker
navigation: True
logo: '/assets/logo.png'
categories: 'analogj'
---

Like many developers, I heard a lot of buzz about Golang (or is it Go, I'm still not sure).
In case you're not familiar with it, it's an open source language developed by Google.
It mostly caught my interest due to the fact that it's pitched as a statically typed, compiled modern language.

For a long time that was the extent of my Golang knowledge. I knew I wanted to take a closer look at
it at some point, but I had other priorities. About 4 months ago, I realized the Golang could be the
solution to one of the problems I was facing with [CapsuleCD](https://github.com/AnalogJ/capsulecd), my application for generically automating
package releases for any language (npm, cookbooks, gems, pip, jars, etc).

<div class="github-widget" data-repo="AnalogJ/capsulecd"></div>


The problem was that [CapsuleCD](https://github.com/AnalogJ/capsulecd) was a executable distributed in a Ruby gem, which meant that anyone
who wanted to use `CapsuleCD` needed to have a Ruby interpreter installed on their build machine, even
if all they were just trying to do was package a Python library. This made my Docker containers bloated,
and more complicated to develop. Wouldn't it be nice to just have single binary I could download into the
container? And so the migration to Golang began, if only in my head at that point.

Over the next couple months, I kept going back to that idea, and a couple weeks ago, I finally sat down and
started porting my ~3000 line Ruby application to Golang. While I could have just bought a book like Golang
for Dummies, I decided to just jump into the coding, and just read blog posts and stack overflow when I got stuck.

I can already hear some of you cringing. To be honest, while I was having a lot of fun, my initial development
was pretty slow. I was trying to write an application in a new language, without knowing any of the conventions.
The thing is, I loved it. Those "Ah-Ha!" moments and getting things compiling again after a huge refactor
were an incredible motivator.

Here's a bunch of the unexpected/unconventional things I learned while porting my app to Golang.

> Please note, these are things that I didn't **expect** when I started writing Golang code with a
background in popular typed and dynamically typed languages, (C++, C#, Java, Ruby, Python and NodeJS).
These are not necessarily criticisms of Golang. I was able to go from 0 -> working release of my software
in a completely new language in 2 weeks. That's pretty awesome if you ask me.

# Before your first line.

## Package Layout
While not required for a compiled language, I was still unprepared for the fact that there doesn't seem to be a **Standard™** folder structure for a Golang library, like there is for Ruby, Chef & Node. There seem to be a couple of popular community structures, and I found myself liking [Peter Bourgon's recommendations](https://peter.bourgon.org/go-best-practices-2016/#repository-structure).

```
github.com/peterbourgon/foo/
  circle.yml
  Dockerfile
  cmd/
    foosrv/
      main.go
    foocli/
      main.go
  pkg/
    fs/
      fs.go
      fs_test.go
      mock.go
      mock_test.go
    merge/
      merge.go
      merge_test.go
    api/
      api.go
      api_test.go
```


## !Circular Dependencies
Package layout becomes even more important when you find out that Golang does't support circular
dependencies between packages. If A imports B, and B imports A, Golang will give up and complain.
I actually kinda like it, as it forced me to think a bit more about my application's domain model.

```
import cycle not allowed
package github.com/AnalogJ/dep/a
  imports github.com/AnalogJ/dep/b
  imports github.com/AnalogJ/dep/a
```

## Dependency management
`npm`, `pypi`, `bundler`. Each of these package managers are synonymous with their language. However Golang
doesn't have an official package manger ([yet](https://github.com/golang/dep)). In the meantime the community
has come up with a [couple](https://github.com/Masterminds/glide) [of](https://github.com/FiloSottile/gvt)
[good](https://github.com/kardianos/govendor) [alternatives](https://github.com/FiloSottile/gvt). The problem
is that they are all really good, and it can be a bit daunting to pick one. I ended up choosing [Glide](https://github.com/Masterminds/glide),
because it has a similar feel to `bundler` and `npm`.

## Documentation
This is actually one of the best things about Golang. `go docs` and the `godoc.org` site are awesome
and standardize the documentation for any library you might use. This is a nice step up from the NodeJS
community where all package documentation is custom and self hosted.

## GOROOT, GOPATH
Golang imports are done in a kind of weird way. Unlike most other languages, Golang basically requires
that your source live in pre-configured folder(s). I'm not going to delve into the details, but you should
know that it takes a bit of setup & getting used to. Dmitri Shuralyov's [How I use GOPATH with multiple
workspaces](https://dmitri.shuralyov.com/blog/18) is a great resource.

```
GOPATH=/landing/workspace/path:/personal/workspace/path:/corporate/workspace/path
```

# Scratching that Itch.

## Pseudo ~~Class~~ Struct Inheritance
The Golang developers did some interesting things when designing the inheritance model. Instead of using
one of the more conventional inheritance models of typed languages like multiple-inheritance or classical
inheritance, Golang follows a multiple composition pattern similar to Ruby.
[Method-Shadowing](https://github.com/luciotato/golang-notes/blob/master/OOP.md#method-shadowing) can
cause some unexpected results if not understood completely.

## Duck-Typed Interfaces
This is another cool unexpected feature of Golang. Interfaces are [duck-typed](https://en.wikipedia.org/wiki/Duck_typing),
something I've only seen in dynamically typed languages. This duck-typing works hand-in-hand with `struct`
composition.

## Structs have fields, Interfaces don't
Unfortunately `structs` can't have the same *API* as `interfaces`, as the latter cannot define fields. This
is not a huge issue, as one can just define a getter and a setter method on the interface, but it was a bit
confusing. I'm sure theres a good technical/CS theory answer for why this is, but yeah.

## Public/Private naming
Golang took Python's `public` and `private` method naming scheme one level further. When I initially found
out that functions, methods and struct names starting with an uppercase character are public and lowercase
are private, I wasn't sure how to feel about it. But honestly, after working with Golang for 2 weeks, I
really like this convention.

```
type PublicStructName struct {}
type privateStructName struct {}
```

## defer
Another surprisingly useful feature Golang. I'm sure it's a result of Golang's parallel processing and
error model, but `defer`'s make it really easy to keep your cleanup close to the originating code. Mentally
I treat it like an alternative to a `finally` method in the `try-catch-finally` pattern or the `using`
block in `C#`/`Java` but I'm sure there are more creative uses for it.

## `go fmt` is awesome
You'll never have the "tabs vs spaces" debate with a Golang developer. There is a standardized Golang
style and `go fmt` can reformat your code to comply with it. It's a neat tool, and reading its source
introduced me to the powerful [`parser`](https://golang.org/pkg/go/parser/) and [`ast`](https://golang.org/pkg/go/ast/) libraries.

## GOARCH, GOOS, CGO & Cross Compiling
My goal of creating a single standalone `CapsuleCD` binary is the entire reason I started my port
to Golang. However it quickly became apparent that simple static binaries aren't an intrinsic feature
of Golang (which should have been obvious). If your code is all written in vanilla Golang, and the code
of all your dependencies (and their dependencies), then you can [build static binaries](http://golangcookbook.com/chapters/running/cross-compiling/)
to your heart's content using `GOOS` and `GOARCH`. However if you're unlucky like I was, and you have
a dependency that calls `C` code under the hood (by importing a `C pseudo-package`) then you're in for
a world of pain. Don't get me wrong, creating a dynamically linked binary is still super easy. But to
generate a static binary, with no external dependencies, means you need to ensure that all your
`C` dependencies (and their dependencies) are all statically linked too. Like I said, obvious.
`C pseudo-packages` are compiled via `CGO`, and you'll need to look at the documentation to find all
the compiler flags necessary to help `CGO` locate your static libraries. A table of all supported GOOS
and GOARCH pairs is located in the [Golang docs](https://golang.org/doc/install/source#environment)


# How do I test this?

## Hidden in plain sight
Test files are suffixed with `_test.go` and should be located side-by-side with the code they test,
rather than relegated to a special testing folder. Its nice, even though it feels a bit cluttered at first.

Test data goes in a special `testdata` folder. Both the `testdata` folder and `_test.go` files are completely
ignored by the compiler during `go build`.

##  `go list` and `vendor` folder
So, dependency management is pretty new to the Golang language, and not all tools understand the special
`vendor` folder. As such, when you run `go test`, by default you'll find it running the tests of all your
dependencies. Use `go list | grep -v /vendor` to get Golang to ignore the vendor folder.

`go fmt $(go list ./... | grep -v /vendor/)`

## `if err != nil`
I'm a stickler for code coverage. I try to keep my open source projects above 80% coverage, but I'm having
a hard time doing that with Golang. Those of you already familiar with Golang will probably just point out that
Golang is one of the easiest languages to get [good coverage in](https://blog.golang.org/cover). Rather
than creating a seperate execution path for errors (`try-catch-finally`) Golang treats all errors as standard objects.
Golang convention states that functions which can produce errors should return them as it's last `return` argument.

It's a pretty interesting model, which reminds me a bit of `Node`'s built-in functions. However, just like `Node`, it can
be difficult to write unit tests that produce errors in built-in functionality. This becomes even more annoying when you follow
a coding pattern where you bubble-up errors, and then handle them at a higher level. When doing this, you'll write alot of
code the looks like the following:

```
data, err := myfunction(...)
if(err != nil){
	return err
}

data2, err2 := myfunction2(...)
if(err2 != nil){
	return err
}

```

This starts to clutter up your code pretty quick. At this point some of you may be thinking that `interface`s and `mock`s
would solve these problems. While that's true in some cases, I don't think it makes sense to write massive `interface`s for
built-in libraries like `os` and `ioutil`, or pass those libraries in as arguments, just so that we can artifically generate
errors for `ioutil.WriteFile` and `os.MkdirAll`.

I'm that this is definitely a shortcoming in my mental-model, but I've read a ton of documentation and blog posts on how
unit tests and code coverage should be done in Golang, and I still haven't found a pattern that makes sense without
seeming to require a dependency injection engine of some sort, something that Golang seems to actively dislike as too cumbersome.

# Conclusion

I'd love to hear your thoughts. I've only been working with Golang for a few weeks, but it's been an incredibly educational
and enjoyable experience. I was able to go from no experience to building a real, working application in Golang in very
little time, not just toy examples from some book. I know that I'm no expert in Golang yet, and that there are still  theory gaps
in my understanding of Golang, but I feel like they are much further apart than I expected when I went down this `self-taught without books` path.

Golang worked exactly as I thought it would, giving me [binaries](https://github.com/AnalogJ/capsulecd/releases) that I can easily download
onto slim Docker containers, without requiring a Ruby interpreter. If you maintain executables in other languages, I would
definitely recommend you consider giving Golang a try.