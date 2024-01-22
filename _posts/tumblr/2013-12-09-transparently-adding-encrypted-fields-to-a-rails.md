---
layout: post
title: Transparently adding encrypted fields to a Rails app using Mongoid
date: '2013-12-09T20:06:00-08:00'
cover: '/assets/images/cover_rails.png'
subclass: 'post tag-post'
tags:
- opensource
- mongodb
- ruby
- ruby on rails
- encryption
- mongoid
redirect_from:
- /post/69538763994/transparently-adding-encrypted-fields-to-a-rails
- /post/69538763994
disqus_id: 'https://blog.thesparktree.com/post/69538763994'
categories: 'analogj'
navigation: True
logo: '/assets/logo.png'

---
As a software architect, you are in the business of designing new applications while balancing business requirements against future utility. Unfortunately design specifications are not as immutable as we dream they are, and sometimes significant changes must be made after the fact.

In the following guide I'll be explaining how to safely add encrypted fields to a Ruby on Rails application using MongoDB.

# Technology Stack

Before getting started you should note that this guide was written and tested to work with the following software, however that does not mean it won't work with your configuration. YMMV.

- Rails 3.2.11
- Ruby 1.9.3p392
- Mongoid

## Mongoid-Encrypted-Fields (v1.2.2)
We will be using the excellent [mongoid-encrypted-fields](https://github.com/KoanHealth/mongoid-encrypted-fields) v1.2.2 gem by KoanHealth to transparently add support for encrypted storage types to Mongoid. `mongoid-encrypted-fields` can encrypt the following Mongoid types:

- Date
- DateTime
- Hash
- String
- Time

Add the following to your `Gemfile`

    gem 'mongoid-encrypted-fields', '~> 1.2.x'

## Symmetric-Encryption (v3.1.0)

While `mongoid-encrypted-fields` provides us with a way to transparently access our encrypted fields, it doesn't actually do the encryption or decryption itself. The gem allows developers to use an encryption library of their choice, and provides an example implementation using the [gibberish](https://github.com/mdp/gibberish) gem. I'm partial to the [symmetric-encryption](https://github.com/reidmorrison/symmetric-encryption) library myself, and so that is what I'll be using in the guide below.

Add the following to your `Gemfile`

    gem 'symmetric-encryption', '~> 3.1.x'

# Preparing your Mongoid models

If you're reading this guide, you've most likely already got a working app using Mongoid. Lets use the following model as a simple example of how your current `Customer` model might look before adding encryption

```ruby
class Customer
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type:String
  field :email, type:String
  field :website, type:String
  field :private_data, type:Hash
end
```

At some point you realize that (you forgot to/you have updated specifications that/management wants to) add encryption to the `private_data` field. Leveraging the `mongoid-encrypted-fields` documentation, all you need to do is change the model to the following:

```ruby
require 'mongoid-encrypted-fields'
class Customer
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type:String
  field :email, type:String
  field :website, type:String
  field :private_data, type: Mongoid::EncryptedHash
end
```

# Initialize mongoid-encrypted-fields and symmetric-encryption

I won't get into creating the `symmetric-encryption` gem configuration file, as you can follow the instructions in their [documentation](https://github.com/reidmorrison/symmetric-encryption#rails-configuration)

Assuming that the configuration is correct and located in the config folder you can use the following commands in your rails initializer to initialize both libraries correctly.

```ruby
SymmetricEncryption.load!('config/symmetric-encryption.yml', 'production')
Mongoid::EncryptedFields.cipher = SymmetricEncryption
```

# Migrate previous data

At this point you're probably thinking that while this is great and all, you already have data stored in your production database. Don't worry, we'll be migrating the existing data next.

The migration task can be done in a Rake task, or using the lovely `mongoid_migration` gem.

The thing to note about the steps below is that the `unset` and `rename` operations are handled by `mongoid` not the `mongoid-encrypted-fields` gem, and as such the encrypt and decrypt operations are not executed. The `migrate_encrypted_field` rake task will not permanently delete your unencrypted data, just rename it. It is reversible if something goes wrong.

	rake migrate_encrypted_field

```ruby
task :migrate_encrypted_field => :environment do
	# Rename the current :private_data field for all customers to :unencrypted_private_data
	p "STEP1 - RENAME private_data to  unencrypted_private_data"
	Customer.each do |customer|
		p "renaming the :private_data field for #{customer["_id"]}"
		if ! customer[:unencrypted_private_data]
		  customer.rename(:private_data, :unencrypted_private_data);
		  customer.unset(:private_data)
		  customer.save!
		else
		  p "unencrypted_private_data found already. skipping"
		end

	end

	# This step will do the actual data encryption and migration back to the :private_data field
	p "STEP2 - ENCRYPT AND SAVE"
	Customer.each do |customer|
	  p "encrypting the data stored in the :unencrypted_private_data field as :private_data for #{customer["_id"]}"
	  customer[:private_data] = customer[:unencrypted_private_data];
	  customer.save!
	end

	# This step will verify that the unencrypted data matches the decrypted data. It will not delete the `unencrypted_private_data` field
	p "STEP3 - VERIFY"
	errored = []
	Customer.each do |customer|
	  p "verifying the data stored in the :unencrypted_private_data field matches the encrypted data stored in :private_data for #{customer["_id"]}"

	  if customer[:unencrypted_private_data]   #make sure that a unencrypted_private_data exists.

		unless customer.private_data != customer[:unencrypted_private_data]
		  p "!!ERROR!! the decrypted data does not match the unencrypted data for #{customer["_id"]}"
		  errored.push credential["_id"]
		end
	  else
		p "unencrypted_private_data not found. Skipping"
	  end
	end

	if errored.length > 0
		p "The following customers produced errors while migrating, please verify manually"
		p errored
	end

end
```

Once the rake task finishes it will automatically print out any `Customer` objects that require manual verification, (something that I never had any problems with). Once you have verified that everything is working correctly it's time to remove the unneeded `unencrypted_private_data` field. Remember, this change cannot be undone.

	rake remove_unencrypted_field


```ruby
task :remove_unencrypted_field => :environment do
	# Permanently remove unencrypted data
	p "STEP4 - PERMANENTLY REMOVE UNENCRYPTED DATA"
	Customer.each do |customer|
		p "renaming the :private_data field for #{customer["_id"]}"
		if customer[:unencrypted_private_data]   #make sure that a unencrypted_private_data exists.
		  customer.unset(:unencrypted_test)
		  customer.save

		else
			p "unencrypted_private_data not found. Skipping"
		end

	end
end
```

If something did go wrong, you can always revert your migration using the following rake task

	rake revert_encrypted_field



```ruby
task :revert_encrypted_field => :environment do
	Customer.each do |customer|
		p "reverting #{customer["_id"]}"
		if customer[:unencrypted_private_data]
			customer.unset(:private_data)
			customer.save!
			customer.rename(:unencrypted_private_data, :private_data);
			customer.save!
		else
		p "did nothing, unencrypted_private_data does not exist"
		end

	end
end
```

# Fin
At this point you should have newly encrypted database field, with all your previous data migrated over. To access your encrypted data transparently, make sure your code is accessing the newly encrypted field as follows:

```ruby
#Transparent (Decrypted) accessor
customer.private_data # => <decrypted hash>

#Encrypted string can be accessed as follows
customer.private_data.encrypted # => <encrypted string>

# It can also be accessed using the hash syntax supported by Mongoid
customer[:private_data] # => <encrypted string></encrypted></encrypted></decrypted>
```
