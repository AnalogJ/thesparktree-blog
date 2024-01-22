---
layout: post
title: 'Go - Serverless Framework - Newrelic'
date: '24-01-21T01:19:33-08:00'
cover: '/assets/images/cover_newrelic.png'
subclass: 'post tag-post'
tags:
- golang
- serverless
- newrelic

navigation: True
toc: true
logo: '/assets/logo.png'
categories: 'analogj'
---


Because I seem to be a glutton for punishment, I decided to build my newest API using Go + Serverless Framework + 
Newrelic. As expected this was difficult for a number of reasons:

- Go is not a first class citizen in the Serverless Framework ecosystem. While it is supported, it is not as well documented as NodeJS.
- Newrelic's AWS Lambda integration has gone through multiple iterations, and their documentation is not clear what is the "best" way to integrate.
    - Newrelic's CloudWatch integration has been deprecated and replaced with a Lambda Layer.
    - The Lambda layer integration [requires code changes in Go, unlike the NodeJS, Python and other integrations](https://github.com/newrelic/serverless-newrelic-lambda-layers/issues/334)
    - The Lambda layer integration only works with the new [Amazon Linux 2023 `provided` runtime](https://aws.amazon.com/blogs/compute/migrating-aws-lambda-functions-from-the-go1-x-runtime-to-the-custom-runtime-on-amazon-linux-2/) instead of the older but more commonly used `go1.x` runtime.
- The Amazon Linux 2023 `provided` runtime has a requirement that the entrypoint binary is named `bootstrap`. This is difficult to do natively with the Serverless Framework, and requires a custom plugin]()
- There is no "agentless" integration for Newrelic. You must install the Newrelic agent in your Lambda function, and then configure your app/code to send data to Newrelic.

Since there doesn't seem to be much public documentation for how to get everything working correctly, I've documented my process below.

<div class="github-widget" data-repo="AnalogJ/newrelic-serverless-go-playground"></div>

## 1. Linking AWS & Newrelic

The Newrelic documentation for [linking your AWS account](https://docs.newrelic.com/docs/serverless-function-monitoring/aws-lambda-monitoring/enable-lambda-monitoring/account-linking/) is pretty thorough,
however the "Linking accounts manually" alternative method was completely broken for me.

While I was unhappy installing another tool on my dev machine, the `newrelic-lambda` cli tool worked perfectly.

```bash
newrelic-lambda integrations install --nr-account-id YOUR_NR_ACCOUNT_ID \
    --nr-api-key YOUR_NEW_RELIC_USER_KEY
```

Here's how you get the Account ID and User Key for use with the CLI:

- [YOUR_NR_ACCOUNT_ID](https://docs.newrelic.com/docs/accounts/install-new-relic/account-setup/account-id/) 
  - From one.newrelic.com, click the user menu, and then go to: Administration > Access management > Accounts to see account IDs.
- [YOUR_NEW_RELIC_USER_KEY](https://docs.newrelic.com/docs/apis/intro-apis/new-relic-api-keys/)
  - Create and manage your API keys from the [API keys UI page](https://one.newrelic.com/launcher/api-keys-ui.api-keys-launcher) so you can start observing your data right away
  - NOTE: You must select a `USER` key, not an `INGEST - *` key, otherwise you'll get an error when attemping to link your account.


Immediately after this step, you should be able to see your AWS account listed in the Newrelic UI. The `newrelic-lambda` cli tool will also 
create a `NEW_RELIC_LICENSE_KEY` secret in your AWS Secrets Manager, which is used by the Newrelic Lambda Layer.


> NOTE: if all you care about is invocation and error metrics, you can stop here. The AWS Integration will allow you to see invocation and error metrics in Newrelic, but you won't be able to see any custom metrics, logs or traces.
> The following steps are required if you would like to see this additional telemetry in Newrelic.


## 2. Serverless Framework - Golang Plugin

The first change we need to make to our Serverless Framework configuration is to add the [Serverless Framework Golang Plugin](https://github.com/mthenw/serverless-go-plugin).

This plugin allows us to build our Go binaries, and and is compatible with the Amazon Linux 2023 `provided` runtime which is required for the Newrelic Lambda Layer.

```yaml
plugins:
  - serverless-go-plugin
...

custom:
  go:
    baseDir: .
    binDir: bin
    cgo: 0
    # compile command, make sure GOOS and GOARCH are set correctly
    cmd: GOARCH=amd64 GOOS=linux go build -ldflags="-s -w"
    # the plugin compiles a function only if runtime is declared here (either on function or provider level)
    supportedRuntimes: ["provided.al2"]
    # builds and archive function with only single "bootstrap" binary, required for `provided.al2` and `provided` runtime
    buildProvidedRuntimeAsBootstrap: true
```

## 3. Serverless Framework - Newrelic Lambda Layer Plugin

Next, we need to add the [Serverless Framework Newrelic Lambda Layer Plugin](https://github.com/newrelic/serverless-newrelic-lambda-layers)

This plugin allows us to add the Newrelic Lambda Layer to our function, which contains a Newrelic agent that will send data to Newrelic.

We need to install the Serverless plugin, specify the provider runtime and then specify the configuration.

- `accountId` - this is the `YOUR_NR_ACCOUNT_ID` value from Step 1
- `apiKey` - this is the `YOUR_NEW_RELIC_USER_KEY` value from Step 1

```yaml
plugins:
  - serverless-newrelic-lambda-layers
...

provider:
  name: aws
  runtime: provided.al2

custom:
  newRelic:
    accountId: YOUR_NR_ACCOUNT_ID
    apiKey: YOUR_NEW_RELIC_USER_KEY
    debug: true

```


## 4. Serverless Framework - IAM Role & IAM Roles Per Function

While the steps above are documented in various locations on the internet, it wasn't clear to me that the Newrelic Lambda Layer requires a specific IAM Role.
I initially tried using `newrelic.ConfigLicense(os.Getenv("NEW_RELIC_LICENSE_KEY"))` to configure the Newrelic `go-agent` sdk, but that didn't work.
What ended up working was the correct IAM Role permissions so that the Newrelic Lambda Layer has the correct permissions to retrieve the Newrelic 
License key from AWS Secret Manager.

```yaml
plugins:
  - serverless-iam-roles-per-function

...

functions:
  healthcheck:
    handler: cmd/health/health.go
    iamRoleStatements:
      - Effect: "Allow"
        Action:
          - "secretsmanager:GetSecretValue"
        # This is the secret that was created by the newrelic-lambda cli tool. 
        # To find it, open the AWS Console, and go to: Secrets Manager > Secrets > Find "NEW_RELIC_LICENSE_KEY", then copy the ARN
        Resource: "arn:aws:secretsmanager:us-east-1:1234567890:secret:NEW_RELIC_LICENSE_KEY-XXXXX"
    events:
      - httpApi:
          path: /health
          method: get

```

## 5. Application Code - Metrics

Finally, we need to modify our Serverless function code to use the `go-agent` sdk.

Notice how the `newrelic.NewApplication()` call has minimal configuration options specified (compared to the [Raw AWS SDK Example](https://github.com/newrelic/go-agent/blob/master/v3/integrations/nrawssdk-v2/example/main.go))

```go
package main
import (
	"context"
	"fmt"

	"github.com/newrelic/go-agent/v3/integrations/nrlambda"
	newrelic "github.com/newrelic/go-agent/v3/newrelic"
)

func handler(ctx context.Context) {
	// The nrlambda handler instrumentation will add the transaction to the
	// context.  Access it using newrelic.FromContext to add additional
	// instrumentation.
	txn := newrelic.FromContext(ctx)
	txn.AddAttribute("userLevel", "gold")
	txn.Application().RecordCustomEvent("MyEvent", map[string]interface{}{
		"zip": "zap",
	})

	fmt.Println("hello world")
}

func main() {
	// Pass nrlambda.ConfigOption() into newrelic.NewApplication to set
	// Lambda specific configuration settings including
	// Config.ServerlessMode.Enabled.
	app, err := newrelic.NewApplication(nrlambda.ConfigOption())
	if nil != err {
		fmt.Println("error creating app (invalid config):", err)
	}
	// nrlambda.Start should be used in place of lambda.Start.
	// nrlambda.StartHandler should be used in place of lambda.StartHandler.
	nrlambda.Start(handler, app)
}
```

## 6. Application Code - Logs

If you had deployed the Serverless function defined in Step 5 as-is, you would see your metrics, however you would not see any logs in Newrelic.
This is because you're missing the last bit of configuration to enable the Newrelic Lambda Extension to send logs to Newrelic.

```go

	app, err := newrelic.NewApplication(
        nrlambda.ConfigOption(),
        
		// This is the configuration that enables the Newrelic Lambda Extension to send logs to Newrelic
        newrelic.ConfigAppLogForwardingEnabled(true),
		func(config *newrelic.Config) {
			logrus.SetLevel(logrus.DebugLevel)
			config.Logger = nrlogrus.StandardLogger()
		},
	)

```


# Fin

That's it! Trigger a deployment, visit your Serverless function & you should now be able to see your Serverless function metrics and logs in Newrelic.

<div class="github-widget" data-repo="AnalogJ/newrelic-serverless-go-playground"></div>


# References
- [Newrelic Lambda Extension Example](https://github.com/newrelic/newrelic-lambda-extension/blob/main/examples/sam/go/main.go)
- [Newrelic Go-Agent SDK Lamdba Example](https://github.com/newrelic/go-agent/blob/master/v3/integrations/nrlambda/example/main.go)
- [Newrelic Go-Agent SDK Full Options](https://github.com/newrelic/go-agent/blob/master/GUIDE.md#full-list-of-config-options-and-application-settings)
- [Newrelic Lambda Layer Supported Runtimes](https://github.com/newrelic/docs-website/blob/develop/src/content/docs/serverless-function-monitoring/aws-lambda-monitoring/get-started/compatibility-requirements-aws-lambda-monitoring.mdx)
- [Newrelic Troubleshooting Guide for Lambdas](https://docs.newrelic.com/docs/serverless-function-monitoring/aws-lambda-monitoring/enable-lambda-monitoring/account-linking/#troubleshooting)
- [Newrelic Troubleshooting Guide for Lambdas - Forum Post - Part 1](https://forum.newrelic.com/s/hubtopic/aAX8W0000008eWv/lambda-troubleshooting-framework-troubleshooting-lambda-part-1)
- [Newrelic Legacy manual instrumentation for Lambda monitoring](https://docs.newrelic.com/docs/serverless-function-monitoring/aws-lambda-monitoring/enable-lambda-monitoring/enable-serverless-monitoring-aws-lambda-legacy/)
- [Newrelic Lambda Layer Plugin for Serverless Framework](https://github.com/newrelic/serverless-newrelic-lambda-layers)
- [Serverless Framework Go Plugin](https://github.com/mthenw/serverless-go-plugin)
