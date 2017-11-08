# Datadog Config

Persist your DataDog configuration in versioned text files which can be edited locally. Pull down existing config and push changes at will.

### Updating to version 2.x
[ ]  Add a key to your environment name called 'tags'  
[ ]  Populate an array of tags in this key.   

```
mydeployment:
  tags:
  - aws
  - p-mysql
```

## Usage

### Setup

    $ cp config/config-example.yml config/config.yml
    # Fill in config.yml with your credentials and other details
    $ bundle install

**CAUTION:** This takes a while and will push to everything.

    $ rake <your-env-name>:push

### Rake commands available

```
rake cf_deployment:console                               # A console with some useful variables
rake cf_deployment:delete_unknown                        # Delete dashboards and alerts that are not represented in local templates for Cf_deployment
rake cf_deployment:emit[metric]                          # emit data to datadog for testing purposes (note this WILL affect graphs and alerts)
rake cf_deployment:eval_alert[path]                      # Evaluate the alert at path under the Cf_deployment config and print to stdout
rake cf_deployment:eval_dashboard[path]                  # Evaluate the dashboard at path under the Cf_deployment config and print to stdout
rake cf_deployment:eval_screen[path]                     # Evaluate the screen at path under the Cf_deployment config and print to stdout
rake cf_deployment:get_alert_json_erb[alert_id,path]     # Make a json template for the specified alert at the given file path
rake cf_deployment:get_dashboard_json_erb[dash_id,path]  # Make a json template for the specified dashboard at the given file path
rake cf_deployment:get_screen_json_erb[screen_id,path]   # Make a json template for the specified screen at the given file path
rake cf_deployment:list_unknown                          # List dashboards and alerts that are not represented in local templates for Cf_deployment
rake cf_deployment:push                                  # Push Cf_deployment Datadog Config
rake diego:cf_deployment:push                            # Push cf_deployment Datadog Config
rake diego:push                                          # Push all Diego Datadog Configs
rake garden:cf_deployment:push                           # Push cf_deployment Datadog Config
rake garden:push                                         # Push all Garden Datadog Configs
rake garden_blackbox:cf_deployment:push                  # Push cf_deployment Datadog Config
rake garden_blackbox:push                                # Push all Garden Datadog Configs
rake spec                                                # Run RSpec code examples
```

Note: `cf_deployment`, as used above, is a placeholder for a deployment named in your `config.yml`, such as `prod`.

## Template directory layout

```
<alert,dashboard,screen>_templates/
├── images
├── prod
├── shared
├── staging
└── tags
```

When the operator runs `rake <environment>:push`, the alert, dashboard, and screen templates are synchronized with Datadog. The templates loaded for each of these synchronizations are chosen as follows:

* Shared templates from the `shared` directory
* Environment specific templates from the `<environment>` directory
* Tag templates that are specified in the configuration for your environment

Tags specified but not found in either `alert_templates`, `dashboard_templates`, or `screen_templates` are ignored for that type.

By example, US-PWS uses the environment name `prod` and several tags, `oss`, `aws`, `jarvice`, etc. When an operator runs `rake prod:push`, the following templates will be included:

* Alert Templates
  * [shared](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/alert_templates/shared)
  * [prod](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/alert_templates/prod)
  * [oss](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/alert_templates/tags/oss)
  * [aws](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/alert_templates/tags/aws)
  * [jarvice](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/alert_templates/tags/jarvice)
* Dashboard Templates
  * [shared](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/dashboard_templates/shared) 
  * [prod](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/dashboard_templates/prod)
  * [aws](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/dashboard_templates/tags/aws)
  * [jarvice](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/dashboard_templates/tags/jarvice)
* Screen Templates
  * [shared](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/screen_templates/shared) 
  * [prod](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/screen_templates/prod)
  * [oss](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/screen_templates/tags/oss)
  * [aws](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/screen_templates/tags/aws)
  * [jarvice](https://github.com/pivotal-cf-experimental/datadog-config-oss/tree/master/screen_templates/tags/jarvice)

### Screen Templates

The screen_templates directory contains all of the template and thresholds for screen boards. Screen templates and thresholds should be located in the same directory as they need to be siblings.

## Workflow
### Dashboards

#### Creating a new deployment
1. Copy `config-example.yml` to `config.yml` and update it to match your environment, see [config.yml](#configyml) section below for more information on the parameters used therein.

#### Creating a new dashboard by importing from DataDog
1. Make sure your `config.yml` file is populated with necessary values. See [config.yml](#configyml) section below for more information.
2. Create a dashboard on the Datadog web UI (Dashboards -> New Dashboard)
3. Import the dashboard by ID, `https://app.datadoghq.com/dash/85829` where 85829 is the dashboard ID.

        bundle exec rake <environment>:get_dashboard_json_erb[<id number>,<path/to/template.json.erb>]

    - Note: do not add a space between the id number and the path. Rake is weird.
    - Note: the filename must end in `.json.erb` for the rake task to find and push the dashboard.
    - Note: this will pull down the dashboard into the given path, replacing the environment specific deployment with <%= deployment %>, the environment specific bosh deployment with <%= bosh_deployment %>, and putting the corresponding variables for the current environment in path/to/template_thresholds.yml.
    - Note: Datadog uses two sets of terminology for dashboards. "Timeboards" in the GUI are "dashboards" in the API/rake tasks. "Screens" or "Screenboards" in the GUI are "screens" in the API/rake tasks. If you get a "Failed to locate" error message you're probably trying to pull a screen with the dashboard task, or vice versa.

4. Commit your changes to source control.

#### Pushing dashboard to datadog
1. Make sure your `config.yml` file is populated with necessary values. See [config.yml](#configyml) section for more information.
2. Push changes to deployment

        bundle exec rake prod:push

### Alerts

#### Creating a new alert from DataDog
Basically the same workflow as dashboards, but with different commands.

        bundle exec rake <environment>:get_alert_json_erb[<id number>,<path/to/template.json.erb>]

#### Pushing alerts to DataDog

        bundle exec rake prod:push

## config.yml
Parameters to the rake tasks and templates are defined in `config/config.yml`.  Each environment can have any key values defined. These key value pairs are used for parsing downloaded templates. Any strings that match the values of these key value pairs will be replaced with ERB syntax.

### Search and replace:
```
search_and_replace:
  my_deployment_name: gobbledygoop
  # For example:
  # datadog.nozzle.mything: {deployment: gobbledygoop } 
  # turns into:
  # datadog.nozzle.mything: {deployment: <%= my_deployment_name %> }
  # 
  # You can also specify distinct search (Regexp) and replace (String) patterns:
  another_key_name:
    search: 'datadog\.nozzle.*\K(gobbledygoop)'
    replace: 'gobbledygoop'
  # This would match the above, but not match:
  # bosh.healthmonitor.mything: { deployment: gobbledygoop }
```

* **metron_agent_deployment_name**: This is the `name` value that is configured for metron_agent. This is sometimes different from the deployment name, namely in PCF deployments
* **deployment**: This is the `name` value in the deployment manifest for your Runtime deployment.  This can also be found via `bosh deployments`.
* **metron_agent_diego_deployment_name**: This is the `name` value that is configured for metron_agent in your Diego deployment. This is sometimes different from the deployment name, namely in PCF deployments
* **diego_deployment**: This is the `name` value in the diego deployment manifest for your Runtime deployment.  This can also be found via `bosh deployments`.
* **bosh_deployment**: If you have a full BOSH deployed in your environment, this is the `name` from its deployment manifest
* **services_deployment**: Corresponding services name to the BOSH deployment
* **micro_deployment**: This is the `name` value in the Micro BOSH deployment manifest.
* **health_screen_image**: Just for fun, this will show up on the main (Runtime) health screen for your environment in the Datadog UI

There are also several email addresses and PagerDuty account names, primarily for monitoring and alerting on PWS.

Threshold values to the templates are defined in `template_thresholds.yml`. These are auto-generated when importing from datadog.
You should also know that these use default values from `prod`. So, while `prod` environment must have every threshold defined, the other environments only need definitions where overrides are in place.

### Params
* **alert_header**: This will add a header to each alert. This can be useful to link operator notes or a Github repo for the environment. Note, this is experimental, and using `get_alert_json_erb` will then include the `alert_header` as text.

## Useful notes
Terminology
* [dashboard](dashboard_templates/README.md)
* [alert](alert_templates/README.md)
* [screenboard](screen_templates/README.md).

### Metric naming conventions

**PLEASE make sure your units are obvious just from reading the metric name.**

* **Good:** `uptime_seconds` and `free_memory_kilobytes`
* **Bad:** `uptime` and `free_memory`

Your teammates will thank you.

### Using Notes in screenboards
Notes are a fantastic way of creating titles for your various sections. You can use markdown, meaning that you can have your titles serve the dual purpose of displaying a title and being clickable to allow for deeper inspection.

We have implemented import code that will detect such links and translate them between environments. However, the code relies on certain semantics to function. When generating the links, use the following format:

```
[Title](/dash/dash/12345) # for dashboards
[Title](/screen/board/12345) # for screenboards
```
Anything else will be left as is.

## Generating fake data to test metrics

Use `rake <env>:emit[some.metric.name]` and follow the command line prompts.
Be careful, as this data may trigger false alarms, so be mindful of what you
are doing.

## Using cf-deployment

When using cf-deployment, make sure to use the
`operations/test/add-datadog-firehose-nozzle.yml` ops file from the
[`cf-deployment`](https://github.com/cloudfoundry/cf-deployment). Set the
`metron_agent_deployment`  and `metron_agent_diego_deployment` in `config.yml` to be the `system_domain` var used in
`cf-deployment`.

## Known issues
- Pulling from non-prod results in thresholds file being incorrect. Be careful here, because this is almost by design. If thresholds vary across envionments, a design decision was made to use production as default values, and allow other environments to override as necessary. This is problematic when it's equal across environments. WIP to be smarter about how to handle. Right now, it will just produce broken threshold files if pulling from non-prod.
- If there are no thresholds defined, it will break again. Just remove the thresholds file.
