---
layout: post
title: You Don't Know Jenkins - Part 1
cover: 'assets/images/cover_jenkins.jpg'
subclass: 'post tag-fiction'
date: '2016-08-16T14:27:07-07:00'
tags:
- Jenkins
- devops
- groovy
- chef
- automation
redirect_from: /post/149039600544/you-dont-know-jenkins-part-1
disqus_id: 'http://blog.thesparktree.com/post/149039600544'
categories: 'analogj'
navigation: True
logo: 'assets/logo-dark.png'
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

- **Part 1 - Automated Jenkins Install using Chef**
- Part 2 - Maintainable Jenkins Jobs using Job DSL *(Coming soon)*
- Part 3 - Leveraging Pipelines for Continuous Deployment/Orchestration *(Coming soon)*
- Part 4 - Advanced DSL & Pipeline Techniques *(Coming soon)*


# Automated Jenkins (Re)Install using Chef

You use configuration management (CM) systems to manage your production services, it only makes sense to do the same for other important internal systems.

It doesn't matter if you use Chef, Ansible, Puppet or Salt. Whichever CM system you choose should do the following:

- Install Jenkins dependencies (like Java)
- Configure server backups
- Configure your Server firewall (eg. iptables)
- Restrict SSH access & other ["first 10 minute" tasks](http://www.codelitt.com/blog/my-first-10-minutes-on-a-server-primer-for-securing-ubuntu/)
- Install Jenkins software
- All company/third party tools required on the build server should be codified
- Create a **single** automation administrator user on Jenkins
- Install Jenkins plugins (and allow specific versions to be specified)
- Credentials & Secrets should be retrieved from a secure data source and configured in Jenkins.
- Configure Jenkins (using xml files on the filesystem, or API calls)
	- security realm/authentication type (eg. LDAP)
	- execution nodes, slaves
	- installation directory
	- views
- Create a **single** bootstrap Jenkins DSL job that polls git for changes (we'll talk about that below)
- Completely disable `configure` access to the Jenkins server.
- Configure your CM system to reconfigure the Jenkins server on a schedule (weekly/monthly you decide), which lets you continuously update to the latest stable release

Here's a few snippets of what this could look like in a Chef cookbook. If you'd like to jump straight to a fully working cookbook you can find it here: [AnalogJ/you-dont-know-jenkins](https://github.com/AnalogJ/you-dont-know-jenkins).
Remember, none of this is unique to Chef, it can be re-implemented in any other CM system.

---

## CLI Authentication

The first thing we need to do is specify our automation user credentials for the Jenkins server.
This is a bit counter intuitive, as this is the first run and we haven't created our automation user or turned on Authentication yet, but on subsequent Chef run this cookbook will fail if the automation user API credentials are not configured.
Thankfully the Chef cookbook is smart enough to use the anonymous user first, and only use the specified credentials if required.

```ruby
# TODO: this private key should be from secret databag
#################################################
# Install Jenkins
#################################################
include_recipe 'jenkins::master'

ruby_block 'run as jenkins automation user' do
  block {
	key = OpenSSL::PKey::RSA.new(data_bag_item(node.chef_environment, 'automation_user')['cli_private_key'])
	node.run_state[:jenkins_private_key] = key.to_pem
  }
end
```

---

## Plugin Management

Before we can do anything on this Jenkins server, we need to make sure it has the proper plugins installed (as some of the following steps will throw exceptions otherwise).
When configuring Jenkins for the first time it can be easy to overlook the importance of controlling your plugin versions. Many a Jenkins server has failed spectacularly after an innocent plugin update. Unfortunately Jenkins doesn't make it easy to lock or install old versions of plugins using its API ([`installNecessaryPlugins` doesn't work](http://stackoverflow.com/a/34778163/1157633)).
I naively thought about [implementing a package management system for Jenkins plugins](https://groups.google.com/forum/#!topic/jenkinsci-users/hSwFfLeOPZo), however after taking some time to reflect, it became clear that re-inventing the wheel was unnecessary.
Jenkins has already solved this problem for [Plugin developers](https://github.com/jenkinsci/gradle-jpi-plugin), and we can just piggy-back on top of what they use.

It's as simple as creating a `build.gradle` file in `$JENKINS_HOME`:

```groovy
buildscript {
  repositories {
	mavenCentral()
	maven {
	  url 'http://repo.jenkins-ci.org/releases/'
	}
  }
  dependencies {
	classpath 'org.jenkins-ci.tools:gradle-jpi-plugin:0.18.1'
  }
}
apply plugin: 'java'
apply plugin: 'org.jenkins-ci.jpi'
repositories {
  maven {
	url 'http://repo.jenkins-ci.org/releases/'
  }
}

dependencies {
	  jenkinsPlugins([
		group: '',
		name: '',
		version: ''
	  ])
}

task clean(type: Delete){
  delete 'plugins'
}

task install(type: Copy, dependsOn: [clean]){
  from configurations.runtime
  include '**/*.hpi'
  into 'plugins'
}

// should be run with `gradle update --refresh-dependencies`
task update(dependsOn: [clean, install])
```

And then executing `gradle install` as part of your cookbook run.

```ruby
template "#{node['jenkins']['master']['home']}/build.gradle" do
  source 'jenkins_home_build_gradle.erb'
  variables(:plugins => node['jenkins_wrapper_cookbook']['plugins'].sort.to_h)
  owner node['jenkins']['master']['user']
  group node['jenkins']['master']['group']
  mode '0640'
end


execute 'install_plugins' do
  command  'plugins.lock'
  EOH
  user node['jenkins']['master']['user']
  group node['jenkins']['master']['group']
  cwd node['jenkins']['master']['home']
end
```

Now you'll have a `plugins.lock` file specifing all the plugins you used, and what version they're at.
Locking your plugins to specific versions is as easy as specifying the version in the `attributes.rb` file

    default['jenkins_wrapper_cookbook']['plugins']['job-dsl'] = {'version' => '1.48'}

You can even update your plugins to the latest version at any time by running `gradle --refresh-dependencies update && gradle dependencies > 'plugins.lock'` and then restarting Jenkins

---

## Automation User

Here's where we create that automation user and populate its credentials.
We'll also set a flag on the filesystem so that we don't continuously regenerate this Jenkins user.
We only want to create a single Jenkins user via Chef, because all subsequent users will be defined in a config file, and won't require a full Chef run to update.

```ruby
#################################################
# Configure Jenkins automation user
#################################################
# TODO: this should be from an encrypted databag
# make sure the plugins were installed before creating your first user because the mailer plugin is required
# before we create any users https://github.com/chef-cookbooks/jenkins/issues/470

automation_user_public_key = OpenSSL::PKey::RSA.new(data_bag_item(node.chef_environment, 'automation_user')['cli_private_key']).public_key
automation_user_public_key_type = automation_user_public_key.ssh_type
automation_user_public_key_data = [ automation_user_public_key.to_blob ].pack('m0')

jenkins_user node['jenkins_wrapper_cookbook']['automation_username'] do
  full_name 'Automation Account - used by chef to configure Jenkins & create bootstrap job'
  public_keys ["#{automation_user_public_key_type} #{automation_user_public_key_data}"]
  notifies :create, 'file[flag_automation_user_created]', :immediately
  not_if { ::File.exist?("#{node['jenkins']['master']['home']}/.flags/automation_user_created")}
end

file 'flag_automation_user_created' do
  path "#{node['jenkins']['master']['home']}/.flags/automation_user_created"
  content ''
  owner node['jenkins']['master']['user']
  group node['jenkins']['master']['group']
  mode '0644'
  action :nothing
end
```

---

## DSL Bootstrap Job

Jenkins automation wouldn't be complete without a way to define and manage Jenkins jobs as code. For that we'll be looking at the
[Job DSL Plugin](https://github.com/jenkinsci/job-dsl-plugin). The Job DSL lets you define any Jenkins job in a groovy DSL that's
easy to understand and well documented. You should store your DSL job definitions in a git repo so they are version controlled and
easy to modify/update. Then all you need is a bootstrap job to pull down your DSL job definition repo and run it on your Jenkins server.

```groovy
#################################################
# Create Bootstrap job using script
#################################################

jenkins_script 'dsl_bootstrap_job' do
  command  branchSpec = Collections.singletonList(new BranchSpec("*/master"));
	List<submoduleconfig> submoduleConfig = Collections.<submoduleconfig>emptyList();

	// If you're using a private git repo, you'll need to specify a credential id here:
	def credential_id = '' // maybe 'b2d9219b-30a2-41dd-9da1-79308aba3106'

	List<userremoteconfig> userRemoteConfig = Collections.singletonList(new UserRemoteConfig(projectURL, '', '', credential_id))
	List<gitscmextension> gitScmExt = new ArrayList<gitscmextension>();
	gitScmExt.add(new RelativeTargetDirectory('script'))
	def scm = new GitSCM(userRemoteConfig, branchSpec, false, submoduleConfig, null, null, gitScmExt)
	job.setScm(scm)

	builder = new javaposse.jobdsl.plugin.ExecuteDslScripts(
	  new javaposse.jobdsl.plugin.ExecuteDslScripts.ScriptLocation(
		  'false',
		  "script/jenkins_job_dsl/simple/tutorial_dsl.groovy",
		  null
	  ),
	  false,
	  javaposse.jobdsl.plugin.RemovedJobAction.DELETE,
	  javaposse.jobdsl.plugin.RemovedViewAction.DELETE,
	  javaposse.jobdsl.plugin.LookupStrategy.JENKINS_ROOT,
	  ''
	)
	job.buildersList.add(builder)
	job.save()

	Jenkins.instance.restart()
  EOH
  notifies :execute, 'jenkins_command[run_job_dsl]'
end

# execute the job using the cli
jenkins_command 'run_job_dsl' do
  command "build '#{node['jenkins_wrapper_cookbook']['settings']['dsl_job_name']}'"
  action :nothing
end
```

At this point we've defined a Jenkins bootstrap job that runs on a daily schedule, clones our DSL defintion repo (using SSH credentials if required)
and creates/updates the jobs on the Jenkins server.

---

## Configure Jenkins
Configuring Jenkins requires a thorough look at the [Jenkins](http://javadoc.jenkins-ci.org/jenkins/model/Jenkins.html) [documentation](http://javadoc.jenkins-ci.org/hudson/model/Hudson.html).
Any setting you can change via the web UI can be set via Jenkins groovy code.

```ruby
#################################################
# Configure Jenkins Installation
#################################################

jenkins_script 'jenkins_configure' do
  command <<-EOH.gsub(/^ {4}/, '')
    import jenkins.model.Jenkins;
    import jenkins.model.*;
    import org.jenkinsci.main.modules.sshd.*;

    instance = Jenkins.instance
    instance.setDisableRememberMe(true)
    instance.setNumExecutors(#{node['jenkins_wrapper_cookbook']['settings']['master_num_executors']})
    instance.setSystemMessage('#{node.chef_environment.capitalize} Jenkins Server - Managed by Chef Cookbook Version #{run_context.cookbook_collection['jenkins_wrapper_cookbook'].metadata.version} - Converged on ' + (new Date().format('dd-MM-yyyy')))

    location = JenkinsLocationConfiguration.get()
    location.setAdminAddress("#{node['jenkins_wrapper_cookbook']['settings']['system_email_address']}")
    location.setUrl("http://#{node['jenkins_wrapper_cookbook']['settings']['system_host_name']}/")
    location.save()

    sshd = SSHD.get()
    sshd.setPort(#{node['jenkins_wrapper_cookbook']['settings']['sshd_port']})
    sshd.save()

    def mailer = instance.getDescriptor("hudson.tasks.Mailer")
    mailer.setReplyToAddress("#{node['jenkins_wrapper_cookbook']['settings']['system_email_address']}")
    mailer.setSmtpHost("localhost")
    mailer.setDefaultSuffix("@example.com")
    mailer.setUseSsl(false)
    mailer.setSmtpPort("25")
    mailer.setCharset("UTF-8")
    instance.save()

    def gitscm = instance.getDescriptor('hudson.plugins.git.GitSCM')
    gitscm.setGlobalConfigName('Jenkins Build')
    gitscm.setGlobalConfigEmail('#{node['jenkins_wrapper_cookbook']['settings']['system_email_address']}')
    instance.save()

  EOH
end
```

---

##Authentication (and Authorization)

- Authentication verifies who you are.
- Authorization verifies what you can do.

One of the great things about Jenkins is that you can specify each independently. Meaning you can offload authentication to your LDAP server, while configuring authorization on a per-job basis if you wanted.

At this point in the guide, all we’re going to do is enable LDAP Authentication and specify Authorization for the automation user. All other user creation and authorization will be done in Part 2 of this guide, rather than in this Chef cookbook. There’s two reasons for this:

- Chef client runs restart the Jenkins service, which we don’t want to do very often.
- We want to make sure we can add Jenkins users at any time, and they should be able to login almost immediately.

Here’s a LDAP Authentication strategy:

```ruby
#################################################
# Enable Jenkins Authentication
#################################################

jenkins_script 'enable_active_directory_authentication' do
  command <<-EOH.gsub(/^ {4}/, '')
    import jenkins.model.*
    import hudson.security.*
    import hudson.plugins.active_directory.*

    def instance = Jenkins.getInstance()

    //set Active Directory security realm
    String domain = 'my.domain.example.com'
    String site = 'site'
    String server = '192.168.1.1:3268'
    String bindName = 'account@my.domain.com'
    String bindPassword = 'password'
    ad_realm = new ActiveDirectorySecurityRealm(domain, site, bindName, bindPassword, server)
    instance.setSecurityRealm(ad_realm)

    //set Project Matrix auth strategy
    def strategy = new hudson.security.ProjectMatrixAuthorizationStrategy()
    strategy.add(Permission.fromId('hudson.model.Hudson.Administer'),'#{node['jenkins_wrapper_cookbook']['automation_username']}')
    instance.setAuthorizationStrategy(strategy)

    instance.save()
  EOH
end
```

---

# Fin.

At this point we have a completely automated Jenkins server.

- Installed all the software required for Jenkins
- Jenkins is installed and configured
- LDAP authentication is enabled
- We have created an automation user (with credentials) so subsequent CM runs can update Jenkins server configuration
- All plugins are managed, and can be locked to an old version easily.
- All Jenkins job configuration is defined in code, and jobs are populated via a bootstrap job.
- No more precious snowflake. You should feel comfortable completely destroying your Jenkins server and rebuilding it at any time.
- The only thing left to do is add additional Jenkins users and configure some more complex Jenkins DSL Jobs.

You’ll be tempted to define multiple users and jobs in your Jenkins CM script. Don’t.

- Most CM systems don’t really understand Jenkins jobs, they just take a XML blob and write it to the filesystem. Jenkins Job XML is verbose and disgusting, and not designed to be edited manually.
- Storing jobs and users in your CM script mean that changes will need to be done through the CM system, which usually restarts the Jenkins service.. not something you want to do often on a busy Jenkins server.
- Defining complex Jenkins jobs in groovy is still a bit nasty, with very little documentation.
- Thankfully this is all solved via the Jenkins DSL which we’ll talk about in Part 2 - Maintainable Jenkins Jobs using Job DSL (Coming Soon)

All code found in this series is available in my github repo: AnalogJ/you-dont-know-jenkins.