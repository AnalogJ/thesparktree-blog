---
layout: post
title: You Don't Know Jenkins - Part 2
date: '2016-08-21T22:37:09-07:00'
cover: '/assets/images/cover_jenkins.jpg'
subclass: 'post tag-post'
tags:
- jenkins
- devops
- groovy
- chef
- dsl
- automation
redirect_from:
- /post/149300867304/you-dont-know-jenkins-part-2
- /post/149300867304
disqus_id: 'http://blog.thesparktree.com/post/149300867304'
categories: 'analogj'
logo: '/assets/logo-dark.png'
navigation: True
---

Jenkins is great. It's the most popular CI/CD tool, with an incredibly active community writing plugins for every api/platform under the sun.
It doesn't matter if you're team has 300 developers or 3, Jenkins can still make your life a lot easier.

Having said all that, over time it can feel like the burdens out-weigh the benefits:

- As your software grows you'll find yourself cloning jobs to setup a new environments (test/stage/prod/etc), which quickly get out of sync with each other.
- Refactoring a large number of jobs can be daunting using the config UI.
- It's easy for Jenkins (or any CI server) to become an untouchable [snowflake](http://martinfowler.com/bliki/SnowflakeServer.html).
Its frightening to even contemplate upgrading your Jenkins version & plugins, let alone building a new Jenkins installation.
- Jenkins freestyle jobs work great for simple CI builds, but as you start using them for deployment & orchestration, you'll start to see their limits

This series is all about solving these common problems using new Jenkins features, modern automation & configuration-as-code practices.

- [Part 1 - Automated Jenkins Install using Chef](http://blog.thesparktree.com/post/149039600544/you-dont-know-jenkins-part-1)
- **Part 2 - Maintainable Jenkins Jobs using Job DSL**
- Part 3 - Leveraging Pipelines for Continuous Deployment/Orchestration *(Coming soon)*
- Part 4 - Advanced DSL & Pipeline Techniques *(Coming soon)*

This is **Part 2 - Maintainable Jenkins Jobs using Job DSL**. If you haven't read [Part 1](http://blog.thesparktree.com/post/149039600544/you-dont-know-jenkins-part-1), you'll want to do that first, as we'll be referring to some concepts defined there.

---

## Maintainable Jenkins Jobs using Job DSL

> If you're not using the [Jenkins DSL](https://github.com/jenkinsci/job-dsl-plugin) plugin to manage your Jenkins jobs,  you're doing yourself, your team and your entire **profession** a disservice. Use it, it's awesome.

We're trying to follow the common practice of `infrastructure as code`, which boils down to managing, provisioning &
configuring servers using machine-processable definition files rather than physically configuring hardware or using interactive configuration tools.

The naive approach would be to just take all the [Jenkins configuration XML files, commit them in git](http://stackoverflow.com/questions/2087142/is-there-a-way-to-keep-hudson-jenkins-configuration-files-in-source-control), and call it a day.

You really don't want to do that: Jenkins Job XML is verbose, plugin version specific and not designed to be edited manually.
Thankfully there's an incredibly powerful alternative: [Jenkins Job DSL plugin](https://github.com/jenkinsci/job-dsl-plugin).
The Job DSL plugin was originally developed at Netflix but it has since been open sourced and is now maintained by the core Jenkins team.

In [Part 1](http://blog.thesparktree.com/post/149039600544/you-dont-know-jenkins-part-1) we created a Jenkins DSL Bootstrap/Seed job
which, when given a Job DSL git repo, would populate the Jenkins server with our simple Jenkins DSL Job:


```groovy
job('DSL-Tutorial-1-Test') {
	scm {
		git('git://github.com/quidryan/aws-sdk-test.git')
	}
	steps {
		maven('-e clean test')
	}
}
```

At a high level, here are some of the things you'll need to do and think about to correctly manage your Jobs-as-code configuration.

- You'll need a git repo to store your Job DSL files.
- Anyone who had Job Configure permission on the Jenkins server should have read (and maybe push) access to this repo.
- Access to the Job configuration page within Jenkins should be disabled for all users. If required for debugging jobs, ensure
that it's understood that all manual changes to jobs will be lost. Your git repo should be the single source of truth for all Job configuration
	- The DSL is simple enough that non-developers who are familiar with Jenkins job configuration page can easily make changes
- Define **every single one** of your Jenkins jobs using the Jenkins DSL plugin.
- Customize your Jenkins bootstrap job to point to your DSL git repo and build on a schedule, or use an SCM trigger.
- Specify Jenkins views and folders in the DSL to logically group your jobs and create nice dashboards
- (Optional) Write [Job DSL tests](https://github.com/jenkinsci/job-dsl-plugin/wiki/Testing-DSL-Scripts) to verify that your Jobs work the way they should.
- (Optional) If you have a complicated Jenkins job structure, you can add tags to your DSL repo, so that you can revert jobs to a previous known working set.


I'm not going to dive deep into the available methods/plugin integrations of the Jenkins DSL in this series, there are much better resources for that:

- [Job DSL API Viewer](https://jenkinsci.github.io/job-dsl-plugin/)
- [Job DSL Commands](https://github.com/jenkinsci/job-dsl-plugin/wiki/Job-DSL-Commands)
- [Real World Examples](https://github.com/jenkinsci/job-dsl-plugin/wiki/Real-World-Examples)

Instead I'll talk about some **advanced** techniques you can use to migrate your complex Jenkins jobs, and make your DSL repo maintainable, even with hundreds of users/developers.

- Factory/Builder pattern using a class library
- Configure Block & Extending the DSL
- Environment Based Configuration
- User management in Code
- Shared Data from Configuration Management

> Please note that I said **advanced**. You'll want to make sure you're comfortable playing around with Groovy & DSL syntax before you try
anything below. Also some of these techniques are only necessary for extremely complicated Jenkins installations
(with multiple environments, large numbers of jobs and/or usage as a deployment & orchestration pipeline)

If you're following along at home using `Vagrant`, you'll want to delete the `dsl-bootstrap-job` and then checkout the `part_2` branch of the [AnalogJ/you-dont-know-jenkins](https://github.com/AnalogJ/you-dont-know-jenkins) repo.
The DSL code has been moved to its own dedicated repo: [AnalogJ/you-dont-know-jenkins-job-dsl](https://github.com/AnalogJ/you-dont-know-jenkins-job-dsl)

<div class="github-widget" data-repo="AnalogJ/you-dont-know-jenkins-job-dsl"></div>

---

## Factory/Builder pattern using a class library

Once you start migrating jobs to the Job DSL, you'll find yourself writing a lot of the same boilerplate code, maybe something like:


```groovy
job(jobName) {
	logRotator(-1, 10, -1, 10)
	//..
	wrappers {
		preBuildCleanup()
		timeout {
			elastic(150, 3, 60)
		}
	}
	//..
	publishers {
		archiveArtifacts('build/test-output/**/*.html')
		//..
		extendedEmail {
			recipientList('engineers@example.org')
			contentType('text/html')
			triggers {
				failure {
					attachBuildLog(true)
				}
			}
		}
	}
}
```

If this was a programming language, you would have refactored out your code to keep things DRY.
Well Jenkins DSL is just Groovy and the plugin lets you specify a relative classpath to load from.
In addition to getting rid of boilerplate code, we can do things like enforce naming rules and customize the jobs
depending on the Chef environment (which we'll talk about below)

In our DSL repo, lets create the following structure (it's not magic, feel free to modify to your needs).
Everything in the `lib` folder is treated as a library that can be refenced by the Groovy files in the root directory.

	lib/companyname/factory/JobFactory.groovy
	lib/companyname/factory/BuildJobFactory.groovy
	factory_pattern_common_dsl.groovy

Lets keep our `JobFactory` class simple for now, all it needs to do is define some base job types,
with a default `logRotator`.

```groovy
// lib/companyname/factory/JobFactory.groovy

package companyname.factory
import companyname.*

public class JobFactory {
  def _dslFactory
  JobFactory(dslFactory){
	_dslFactory = dslFactory
  }

  def myJob(_name, _description) {
	return _dslFactory.freeStyleJob(_name){
	  description "DSL MANAGED: - $_descripton"
	  logRotator(-1, 10, -1, 10)
	}
  }

  def myMavenJob(_name, _description) {
	return _dslFactory.mavenJob(_name){
	  description "DSL MANAGED: - $_descripton"
	  logRotator(-1, 10, -1, 10)
	}
  }
}
```
Now lets create a `BuildJobFactory` that inherits from the simple `JobFactory`. It defines another a slightly more
complex `baseBuildRpmJob` that will be used by all build jobs, and (optionally) also defines a `buildWebAppRpmJob` which has all the rest of the configuration specific to the job, like SCM, ant tasks.

```groovy
// lib/companyname/factory/BuildJobFactory.groovy

package companyname.factory
import companyname
import groovy.transform.* //this is required for the @InheritConstructors decorator

@InheritConstructors
public class BuildJobFactory extends JobFactory {

  // Define a base build job
  def baseBuildRpmJob(_name,_description){
	def job = myJob(_name, _description)
	job.with{
	  logRotator(-1, 50, -1, 20)
	  publishers {
		archiveArtifacts('dist/**')
		fingerprint('dist/**')
	  }
	}
	return job
  }

  // Define specific jobs
  def buildWebAppRpm() {
	def job = baseBuildRpmJob('Build-Webapp-RPM', 'Builds the web app v1 RPM')
	job.with{
	  scm {
		// your scm (git/hg/perforce/..) repo config here
	  }
	  steps {
		ant('build-webapp-rpm')
		ant('test-webapp')
	  }
	}
	return job
  }
}
```

Ok. So inheritance is a thing. Now what? How do we actually add this job to Jenkins?
Lets fill out the `factory_pattern_common_dsl.groovy` file.

```groovy
// factory_pattern_common_dsl.groovy

import companyname.*
import companyname.factory.*

def buildJobFactory = new BuildJobFactory(this)
buildJobFactory.buildWebAppRpm()
buildWebAppRpm.baseBuildRpmJob('Build-Dynamically-Defined-Rpm')
  .with{
	scm {
		// your scm (git/hg/perforce/..) repo config here
	}
	steps {
		ant('build-dynamic-rpm')
		ant('test-dynamic')
	}
  }
```

The key thing to pay attention to in these examples is the `.with {}` function. It allows us to reopen and extend a closure defined in a `Factory`.

Finally, lets modify our Jenkins cookbook bootstrap job to point to this new DSL repo, and reference this `lib/` classpath

You can take a look at the exact changes here: [part_2_factory branch diff](https://github.com/AnalogJ/you-dont-know-jenkins/compare/part_2_factory)

At this point we should have 2 new jobs on our Jenkins server: `Build-Webapp-RPM` defined in the `BuildJobFactory` and
`Build-Dynamically-Defined-Rpm` which was defined in the actual DSL. Later on we'll discuss why we might want to dynamically
define jobs in the DSL instead of in a `Factory`, its primarily related to Environment specific overrides.
It's best not to mix these two patterns unless you really do have multiple Jenkins environments built from the same DSL code base.

---

## Configure Block & Extending the DSL

At some point you'll run into a <strike>unmaintained</strike> niche plugin that's not currently supported by the DSL. If you're lucky you might be
able to use the [Automatically Generated DSL](https://github.com/jenkinsci/job-dsl-plugin/wiki/Automatically-Generated-DSL).
But lets be honest, you're not that lucky.

The first thing you're going to want to do is manually configure that plugin using the Job configure UI, and save the job.
Then you'll want to open up the job's `config.xml` file and look for XML node the plugin created. Here's the XML that the
`filesystem` plugin added:

```xml
<scm class="hudson.plugins.filesystem_scm.FSSCM"><path>/example/path/on/filesystem</path><clearworkspace>false</clearworkspace><copyhidden>false</copyhidden><filterenabled>false</filterenabled><includefilter>false</includefilter><filters></filters></scm>
```

Great, now we need to translate that to something the DSL understands using the `configure` block.

```groovy
// lib/extensions/FilesystemScm.groovy

package companyname.extensions
class FilesystemScm {

  // based off https://github.com/jenkinsci/job-dsl-plugin/wiki/The-Configure-Block#configure-svn
  static Closure filesystem(String _path, boolean _copyHidden = false, boolean _clearWorkspace = false){
	return { project ->
	  project.remove(project / scm) // remove the existing 'scm' element
	  project / scm(class: 'hudson.plugins.filesystem_scm.FSSCM') {
		  path _path
		  clearWorkspace _clearWorkspace
		  copyHidden _copyHidden
		  filterEnabled 'false'
		  includeFilter 'false'
		  filters ''
	  }
	}
  }
}
```

If the syntax is unfamiliar, don't worry it's actually not too complicated, the DSL plugin wiki is a [great explanation](https://github.com/jenkinsci/job-dsl-plugin/wiki/The-Configure-Block#transforming-xml).
The cool thing is that almost every plugin supported by the DSL has an option configure block as well, so if you want to
use a new feature that isn't yet supported by the DSL, you can add it in the plugin's configure block.

Now you can call this <strike>terrible</strike> plugin in your DSL definitions or in a `Factory`:

```groovy
// factory_pattern_common_dsl.groovy

import companyname.*
import companyname.factory.*
import companyname.extensions.*

buildWebAppRpm.baseBuildRpmJob('Build-Dynamically-Defined-Rpm')
	.with{
		//..
	configure FilesystemScm.filesystem('/opt/local/filepath/')
	//..
  }
```

---

## Environment Based Configuration

Lets talk about multiple deployment environments. As your product matures you'll find yourself needing to create multiple
versions of your application for testing and validation reasons. This could be as simple as dedicated `development`, `stage` and `prod`
stacks, but it could be as complicated as creating a completely functional stack in the cloud for each commit or pull request,
 and then destroying it after.

Either way you'll find yourself creating Jenkins jobs that are basically clones of each other, but may have different parameters, slave labels or
notification rules. Using the `Factory` pattern above you can easily create reusable template jobs and customize them for each environment,
but how do you organize them?

Depending on if you have a single Jenkins server with multiple slaves or a dedicated Jenkins server per environment,
you'll probably want to [organize some of your Jobs into folders](https://github.com/jenkinsci/job-dsl-plugin/wiki/Job-DSL-Commands#folder) using the [Jenkins Folder Plugin](https://wiki.jenkins-ci.org/display/JENKINS/CloudBees+Folders+Plugin)
and/or modify your bootstrap job to load a `*_dsl.groovy` file depending on your Chef environment.

Organizing your DSL files for a dedicated Jenkins server per environment is easy. Lets take our existing DSL
repo folder structure and add the following files:

	dev/dev_customized_jobs_dsl.groovy
	dev/dev_customized_qe_jobs_dsl.groovy
	stage/stage_customized_jobs_dsl.groovy
	prod/prod_customized_jobs_dsl.groovy

And then we can modify the DSL seed job to load the common jobs as well as any environment specific jobs:

    script/factory_pattern_common_dsl.groovy
    script/{environment name}/*.groovy

Here's where we made that change in our Chef [jenkins_wrapper_cookbook](https://github.com/AnalogJ/you-dont-know-jenkins/blob/part_2/jenkins_wrapper_cookbook/recipes/default.rb#L214).


---

## User management in Code

Now for the main event. In part one we spun up a bare-bones Jenkins server.
While we installed all the right software and configured the Jenkins server, we only created a single user, for the dedicated use of our configuration management system.

> Before we go any further, let me be clear. We will be adding new users (and their associated **security** roles) to Jenkins using
**automation**. If the words security and automation in the same sentence are giving you anxiety, that's good.
> You should analyze the security of your corporate network, git server and Jenkins server credential access before you even
consider automating user creation. At the same time, you should weigh it against the time spent managing users and permissions
and the benefits of partial self-service.

With all that out of the way, lets get started. Jenkins supports multiple security models, but I'll be talking about `Project Matrix Authorization` which is the most granular.
In our DSL repo we'll be creating a `Utilities.groovy` file with our security related methods.

```groovy
// lib/companyname/Utilities.groovy

public class Utilities {
  static populateUserAuthorization(out, user_permissions) {

	if (!Jenkins.instance.isUseSecurity()) {
	  out.print "--> no authorization strategy found. skipping user management."
	  return
	}
	out.println "--> retrieving and verifying project matrix authorization strategy"
	if (Jenkins.instance.getAuthorizationStrategy().getClass().getName() != "hudson.security.ProjectMatrixAuthorizationStrategy"){
	  out.println "--> authorization strategy is not matrix authorization. skipping user management."
	  return
	}

	//create a new strategy so that we can guarantee that only the users specified have permissions to Jenkins.
	def strategy = Jenkins.instance.getDescriptor("hudson.security.ProjectMatrixAuthorizationStrategy").create()

	out.println('--> Set permissions for automation users:')
	addUserPermissionsToStrategy(strategy, Constants.automation_username, ['hudson.model.Hudson.Administer'], out)

	out.println('--> add permissions for each specified user')
	user_permissions.each{ k, v ->
	  addUserPermissionsToStrategy(strategy, k, v, out)
	}

	out.println('--> set the project matrix authorization strategy')
	Jenkins.instance.setAuthorizationStrategy(strategy)
  }

  static addUserPermissionsToStrategy(strategy, user, permissions, out){
	out.println("--> adding ${user}:${permissions}")
	permissions.each { perm_string ->
	  strategy.add(Permission.fromId(perm_string), user)
	}
  }
}
```

Now we'll create a `users.groovy` file in each environment folder so that we can have a managed list of authorized users for each environment.

```groovy
// dev/users.groovy

import companyname.*
/*
# This file defines the users that have access to the Jenkins server, folders and their permissions.
# You can specify permissions for unauthenticated users by using the "anonymous" username
#
# The following permissions are available on Jenkins:
#  hudson.model.Hudson.Administer,
#  hudson.model.Hudson.ConfigureUpdateCenter,
#  hudson.model.Hudson.Read,
#  hudson.model.Hudson.RunScripts,
#  hudson.model.Hudson.UploadPlugins,
#  hudson.model.Computer.Build,
#  hudson.model.Computer.Build,
#  hudson.model.Computer.Configure,
#  hudson.model.Computer.Connect,
#  hudson.model.Computer.Create,
#  hudson.model.Computer.Delete,
#  hudson.model.Computer.Disconnect,
#  hudson.model.Run.Delete,
#  hudson.model.Run.Update,
#  hudson.model.View.Configure,
#  hudson.model.View.Create,
#  hudson.model.View.Read,
#  hudson.model.View.Delete,
#  hudson.model.Item.Create,
#  hudson.model.Item.Delete,
#  hudson.model.Item.Configure,
#  hudson.model.Item.Read,
#  hudson.model.Item.Discover,
#  hudson.model.Item.Build,
#  hudson.model.Item.Workspace,
#  hudson.model.Item.Cancel
#
# Make it easy on us and list your username in alphabetical order.
*/

def user_permissions = [
  //TODO: this is definitely not something you'll do in production, it's just so that you can validate the
  //DSL worked correctly in Vagrant
  'anonymous': ['hudson.model.Hudson.Administer'],

  'alice.name': ['hudson.model.Hudson.Administer'],
  'bob12': ['hudson.model.Hudson.Read', 'hudson.model.Item.Build', 'hudson.model.Item.Workspace'],
  'char.lie': ['hudson.model.Hudson.Read', 'hudson.model.Item.Build',]
]

Utilities.populateUserAuthorizationPerFolder(out, user_permissions)
```

Now we have all our users defined in text, permissions are easy to update and there's a built in audit system - git.
To ensure that user's don't just add themselves as Administrators or wreak havoc on your Job configurations,
you could enable read-only access to the Git repo, and tell users to create pull requests.
Setting the DSL bootstrap job to run overnight would also ensure that newly added/removed permissions are kept in-sync on Jenkins.

---

## Shared Data from Configuration Management

As you invest time creating a robust Jenkins installation, you'll find yourself wishing to share data between your Configuration Management
system (Chef, Ansible, Puppet, etc) and the Job DSL. While this should be limited as much as possible, occasionally
you'll find that you have no alternative.

This can be done by chaining the [`readFileFromWorkspace`](https://github.com/jenkinsci/job-dsl-plugin/wiki/Job-DSL-Commands#reading-files-from-workspace) command in the Job DSL,
with the Groovy [`JsonSlurper#parseText()`](http://groovy-lang.org/json.html) method and your CM system's ability to write
template files to the filesystem.

In Chef this could look like:

```ruby
file "#{node['jenkins']['master']['home']}/chef_environment_data.json" do
	content lazy {
		JSON.pretty_generate(
			:chef_environment_name => node.chef_environment,
			:important => node['my']['attribute']['here'],
			:data => node['another']['one']
		)
	}
	owner node['jenkins']['master']['user']
	group node['jenkins']['master']['group']
end
```

Then copy it into the DSL job workspace as part of your bootstrap job:

```groovy
def shellStep = new hudson.tasks.Shell('cp -f $HUDSON_HOME/chef_environment_data.json $WORKSPACE/chef_environment_data.json')
job.buildersList.add(shellStep)
```

And then finally read it and parse it anywhere you have access to the DSL context (like in a `_dsl.groovy` file or inside your `Factory` classes)

```groovy
new JsonSlurper().parseText(readFileFromWorkspace('chef_environment_data.json'))
```

---

# Fin.

Even if you didn't use any of the techniques in this guide, out of the box you'll get the following with the DSL plugin:
- You can update your Jenkins job configurations by just updating a git repo, no CM run or cookbook packaging required
- You have a history of what changes were made, who made them, and (hopefully) why they were made.
- The DSL will automatically cleanup managed jobs that are no-longer required

Now that we have a Jenkins server with actual build jobs, lets see how we can use Pipelines to automate Orchestration & Deployment
with Jenkins.

**Part 3 - Leveraging Pipelines for Continuous Deployment/Orchestration** *(Coming soon)*

In Part 3 we'll talk about the common pitfalls & workarounds with Pipelines (serialization errors, scriptApproval, groovy CPS, parameter handling),
as well as some of the incredibly cool things you can do with them (user input, stages, deployment job chains, credential scopes,
flyweight vs heavyweight context, libraries)

All Chef found in this guide is available in the `part_2` branch of [AnalogJ/you-dont-know-jenkins](https://github.com/AnalogJ/you-dont-know-jenkins) and all DSL code is available in the [AnalogJ/you-dont-know-jenkins-job-dsl](https://github.com/AnalogJ/you-dont-know-jenkins-job-dsl) repo.