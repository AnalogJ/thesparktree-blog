---
layout: post
title: You Don't Know Jenkins - Part 3
date: '2017-11-13T22:37:09-07:00'
cover: '/assets/images/cover_jenkins.jpg'
subclass: 'post tag-post'
tags:
- jenkins
- devops
- groovy
- chef
- dsl
- automation
categories: 'analogj'
logo: '/assets/logo-dark.png'
navigation: True
---


With the release of Jenkins 2.x, support for Pipeline jobs is built-in. This is important for multiple reasons, but mostly
because Pipeline jobs are now the defacto standard for creating complex jobs, custom deployment workflows without
additional plugins. The best part is that pipelines are basically just Groovy scripts with some Jenkins specific
additions.

While Pipeline jobs can be used to build artifacts just like a regular Freestyle job, their true power is only apparent when you
start using the Pipeline for orchestration.

Before Pipelines were released you had to make use of post build triggers and artifact archiving to create a useful 
orchestration workflow. With Pipelines, this concept is now a first class citizen. You can clone multiple repositories, 
trigger down stream  jobs, run stages in parallel, make decisions about what stages to run based on parameters. You 
have the power to build a Pipeline that suites your needs.

---

## Declarative vs Scripted Pipeline

The first thing you need to know is that there's actually 2 significantly different types of pipelines.

The first type is called a `Declarative Pipeline`. If you're familiar with a `Jenkinsfile`, then you're already with the 
Declarative Pipeline syntax. Its simple and structured, making it easy to understand.

The second type is called a `Scripted Pipeline`. It is a fully featured programming environment, offering a tremendous 
amount of flexibility and extensibility to Jenkins users.

The two are both fundamentally the same Pipeline sub-system underneath. They are both durable implementations of "Pipeline as code." 
They are both able to use steps built into Pipeline or provided by plugins. Both are able utilize Shared Libraries 
(a topic we'll dive into in Part 4 *(Coming soon)*).

Where they differ however is in syntax and flexibility. Declarative limits what is available to the user with a more 
strict and pre-defined structure, making it an ideal choice for simpler continuous delivery pipelines. Scripted provides 
very few limits; the only limits on structure and syntax tend to be defined by Groovy itself, rather than any Pipeline-specific 
systems, making it an ideal choice for power-users and those with more complex requirements.

For the most part the issues and solutions I talk about in the following sections are relevant to both types of Jenkins 
Pipeline, however some only apply to Scripted.

---

## Serialization woes

If you've worked with Jenkins Pipelines for anything more than simple/toy examples, you'll have run into `java.io.NotSerializableException` exceptions.

These exceptions are confusing, until you begin to understand the truth about Pipelines & Jenkinsfiles: You're not writing 
a groovy script, you're writing a list of groovy scripts.

I could dive deep into Abstract Syntax Tree (AST), the `Groovy-CPS` engine and continuation-passing style transformation, 
but as a developer writing Jenkinsfiles and pipeline scripts you probably just want to get your script working.

Here's what you need to know: after each pipeline `step` Jenkins will take a snapshot of the current execution state.

This is because Jenkins pipelines are supposed to be robust against restarts (they can continue where they left off, 
rather than requiring your pipeline to start over from the beginning). While this sounds great, the way Jenkins does 
this is by serializing the current pipeline state. If you're using classes that do not serialize nicely 
(using `implements Serializable`) then Jenkins will throw an error.

### Solutions

There's a couple of solutions for this:

- `@NonCPS` decorated methods may safely use non-`Serializable` objects as local variables, though they should not accept 
non-serializable parameters or return or store non-serializable values.

	```groovy
	@NonCPS
	def version(text) {
	  def matcher = text =~ '<version>(.+)</version>'
	  matcher ? matcher[0][1] : null
	}
	```

- All non-serializable variables should be `Null`ed before the next Jenkins pipeline step is called.

	```groovy
	def matcher = readFile('pom.xml') =~ '<version>(.+)</version>'
	if (matcher) {
		echo "Building version ${matcher[0][1]}"
	}
	matcher = null
	sh "${mvnHome}/bin/mvn -B -Dmaven.test.failure.ignore verify"
	```

- Use `implements Serializable` for any classes that you define yourself. Only really applicable in Shared Libraries 
(detailed in You Don't Know Jenkins - Part 4 *(Coming soon)*)

	```groovy
	class Utilities implements Serializable {
	  def steps
	  Utilities(steps) {this.steps = steps}
	  def mvn(args) {
	    steps.sh "${steps.tool 'Maven'}/bin/mvn -o ${args}"
	  }
	}
	```

---

## Script Approval & Groovy Sandbox
Pipelines also introduce another annoyingly common exception `org.jenkinsci.plugins.scriptsecurity.sandbox.RejectedAccessException`.

Like the `Serialization` error above, this related to the magic that makes Jenkins Pipeline Groovy different than regular 
Groovy scripts. Since Groovy is a full programming language, with all the functionality and potential destructiveness that 
entails, the Jenkins developers decided to mitigate that potential for harm by only allowing certain whitelisted methods 
to be used in Pipeline scripts.

Unfortunately a large number of common legitimate Groovy methods are not whitelisted by default, which can make Pipeline 
development frustrating.
Even more frustrating is the fact that the `RejectedAccessException`'s are only thrown at Runtime, potentially 2 hours 
into a 3 hour pipeline script. Yeah, not fun.

### Solutions

There's a couple ways to mitigate these issues:
- Disable the Jenkins Pipeline sandbox. While this may be ok while developing a new script, this shouldn't be your default 
for finished scripts. The Pipeline Groovy runtime has access to all the Jenkins internals, meaning you can retrieve encrypted 
credentials, trigger deployments, delete build artifacts and cause havoc in any number of ways.
- Whitelist each and every method that you use. If you make heavy use of Groovy shortcut methods in `DefaultGroovyMethods` 
(like `.any` `.each`, `.find`) you'll want to take a look at my [Jenkins init.d script](https://github.com/AnalogJ/you-dont-know-jenkins-init/blob/master/5000.script-approval.groovy#L15-L23) 
that automatically whitelists them all.
- Global Shared Libraries. I'll talk about this more in Part 4 *(Coming soon)*, but Global Pipeline Libraries are assumed 
to be trusted, and as such any methods (no matter how dangerous) are not subject to the Jenkins security sandbox.

---

## Documentation

There's a lot of documentation about Pipelines, however they are spread out between various Github repos, the Jenkins Blog 
and the official documentation. I'm going to list links and sources here that you'll find useful for various topics.

### Steps

Documentation can be a bit hard to find, especially if you want an updated list of all the available pipeline steps.

You're best bet is to check the master list: [Pipeline Steps Reference](https://jenkins.io/doc/pipeline/steps/). It 
contains documentation for all the known pipeline steps provided by plugins.

If however you're only interested in the steps that are actually usable on your Jenkins server, you'll want to go to 
`http://{{JENKINS_URL}}/pipeline-syntax/html`. While that website is fully featured, the documentation can be a bit 
terse, so you'll also want to check out the Snippet Generator: `http://{{JENKINS_URL}}/pipeline-syntax`

### Pipeline

While you might already be familiar with Pipelines, sometimes looking at actual code is more useful than reading about 
an abstract concept.

The Jenkins team has a [jenkinsci/pipeline-examples](https://github.com/jenkinsci/pipeline-examples) with working code 
for Pipelines, Jenkinsfiles and Shared Libraries. You should definitely check it out.

If you've already written a couple Pipeline scripts and you're starting to get comfortable, then it may be time to start 
reading about the [Best Practices](https://github.com/jenkinsci/pipeline-examples/blob/master/docs/BEST_PRACTICES.md)

---

## Loading External Jars and Shared Libraries

Pipelines are powerful, but to really see them shine, you'll want to start importing third party jars and reusing code.

Importing Jars from the public maven repo is as easy as including `@Grab` at the top of your Pipeline script.

```groovy
@Grab('org.yaml:snakeyaml:1.17')
import org.yaml.snakeyaml.Yaml
```

Reusing Pipelines functions is easy too, just move your code into a Shared Library, configure it as a Library in the 
Jenkins Manage page, and then import it in your Pipeline script

```groovy
@Library('somelib')
import com.mycorp.pipeline.somelib.UsefulClass
```
I'll be talking about Shared Pipelines more in Part 4 *(Coming soon)* of this series, with much more detail.

---

## String Interpolation & Multiline Strings

While this is mostly just about Groovy syntax, and not really Jenkins Pipeline specific, I've found that there are a 
lot of questions around `String` manipulation and multiline strings.

String interpolation is pretty easy. All you need to know is that single quotes (`'`) are literal strings, while double 
quoted strings support interpolation and escape characters.

```groovy
def myString = 'hello'
assert '${myString} world' == '${hello} world'
assert "${myString} world" == 'hello world'
```

Multiline strings are easy to create as well, just create use three single or double quotes to open and close the string. 
As before, single quotes are literal multi-line strings, while double quotes are used for interpolated multi-line strings

```groovy
def myString = 'hello'

assert '''\
${myString} world
foo bar
''' == "\\\n${myString} world\nfoo bar\n"

assert """\
	${myString} world
	foo bar
""".stripIndent() == "hello world\nfoo bar\n"
```

---

## Shell Output Parsing

A little known but incredibly useful feature of the pipeline shell `sh` step, is that you can redirect the STDOUT into a groovy variable.

```groovy
def gitCommit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
echo "Git commit sha: ${gitCommit}"
```

---

## Build Name & Description

Occasionally you'll wish that you could include more contextual data in your build history, instead of having to identify a specific build by build number.

Pipeline's have you covered:

![](http://static1.tothenew.com/blog/wp-content/uploads/2016/05/Jenkins_failed.png)

At any point in your pipeline script you can add/update the job name (build ID) & description using the global variable `currentBuild`.

```groovy
//this will replace the build number in the Jenkins UI.
currentBuild.name = "short string"

//this will show up as a grey text block below the build number
currentBuild.description = "my new description"

```

---

# Fin.

Pipelines are completely customizable and extensible, making it hard to give you a out-of-the-box solution, like I've done in previous guides.

Instead the goal here was to answer the common questions I've seen about Pipelines and throw in some links and resources 
so you can build a Pipeline that works for you.

Having said that, Pipeline scripts are only one half of the solution.

**Part 4 - Advanced Techniques - Pipeline Testing, Shared Libraries** *(Coming soon)*

In Part 4 we'll talk about how you can actually start testing your Pipeline scripts. As you start writing more orchestration 
code you'll find that, unlike application code, orchestration code is incredibly difficult to write and test effectively.

In addition, any discussion about Pipelines wouldn't be complete without mentioning Shared Libraries. I've touched on them 
a couple times in this guide, but in Part 4, I'll be writing a complex & testable Shared Library, step by step so you can follow along.

### Additional References
- https://jenkins.io/solutions/pipeline/
- https://jenkins.io/doc/book/managing/script-approval/
- https://github.com/jenkinsci/pipeline-plugin/blob/master/TUTORIAL.md
- https://jenkins.io/doc/book/pipeline/shared-libraries/
