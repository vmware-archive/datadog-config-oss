# Datadog Config

This is the authoritative definition of the dashboards and alerts in Datadog for production and staging.
Do not modify the dashboards and alerts directly in Datadog; instead modify the template files here and run the sync process.

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

Note: 'cf_deployment', as used above, is a placeholder for a deployment name, such as 'prod'.

## Workflow
### Dashboards / Screenboards
#### Creating a new deployment
1. Copy `config-example.yml` to `config.yml` and update it to match your environment, see config.yml section below for more information on the parameters used therein.

#### Creating a new dashboard by importing from DataDog
1. Make sure your ```config.yml``` file is populated with necessary values. See config.yml section below for more information.
2. Create a dashboard on the Datadog web UI (Dashboards -> New Dashboard)
3. Import the dashboard by ID, ```https://app.datadoghq.com/dash/85829``` where 85829 is the dashboard ID.

        bundle install
        bundle exec rake <environment>:get_dashboard_json_erb[<id number>,<path/to/template.json.erb>]

    - Note: do not add a space between the id number and the path. Rake is weird.
    - Note: the filename must end in ```.json.erb``` for the rake task to find and push the dashboard.
    - Note: this will pull down the screenboard into the given path, replacing the environment specific deployment with <%= deployment %>, the environment specific bosh deployment with <%= bosh_deployment %>, and putting the corresponding variables for the current environment in path/to/template_thresholds.yml.

4. Commit your changes to source control.

#### Pushing dashboard to datadog
1. Make sure your ```config.yml``` file is populated with necessary values. See config.yml section for more information.
2. Push changes to deployment
        rake prod:push

### Alerts

#### Creating a new alert from DataDog
Basically the same workflow as dashboards, but with different commands.

        bundle install
        bundle exec rake <environment>:get_alert_json_erb[<id number>,<path/to/template.json.erb>]

#### Per-job alerts
If you need an alert such that you have one unique alert per job (job being DEA, router, etc.), add to the `per_job_alert_templates` folder.

The name/title is used as a unique key; alerts/dashboards with the same name/title will be overwritten.

#### Pushing alerts to DataDog

        bundle install
        rake prod:push

## config.yml
Parameters to the rake tasks and templates are defined in `config/config.yml`.  Each environment can have the following values defined:

* **deployment**: This is the `name` value in the deployment manifest for your Runtime deployment.  This can also be found via `bosh deployments`.  NOTE: for Diego deployments, it's assumed that the name of your Diego deployment is `${name_of_cf-deployment}-diego`
* **bosh_deployment**: If you have a full BOSH deployed in your environment, this is the `name` from its deployment manifest
* **services_deployment**: Corresponding services name to the BOSH deployment
* **micro_deployment**: This is the `name` value in the Micro BOSH deployment manifest.
* **health_screen_image**: Just for fun, this will show up on the main (Runtime) health screen for your environment in the Datadog UI
* **router_elb_name**: The name given to the ELB for this deployment's router
* **stoplights_screen_id**: The numeric ID that Datadog has assigned your screen
* **params**: Used to inject configuration values into your ERB file ```<%= params.fetch('min_deas_that_can_stage') %>```
* **credentials.api_key**: API key for the Datadog account where your dashboards will be created.
* **credentials.api_key**: App key for the Datadog account where your dashboards will be created.
* **jobs**: An enumeration of the various jobs associated with the deployment that you want to monitor, such as 'cloud_controller', 'nats', etc.

There are also several email addresses and PagerDuty account names, primarily for monitoring and alerting on PWS.

Threshold values to the templates are defined in `template_thresholds.yml`. These are auto-generated when importing from datadog.
You should also know that these use default values from 'prod'. So, while 'prod' environment must have every threshold defined, the other environments only need definitions where overrides are in place.

## Folder structure

```
screen_templates/
├── images
├── prod
├── shared
└── staging
```

The screen_templates folder contains all of the template and thresholds for screen boards.  Templates in the 'shared' folder are pushed to all of the environemnts, while templates in e.g. the 'prod' folder will only be pushed to the prod DataDog.  Move the template json/erb file to the
appropriate folder and move the thresholds yaml to the same folder so that the two files are siblings.

Edit the resultant file to make sure that the auto-gsub bit didn't mangle something that wasn't supposed to be static. Check [here for further](lib/screen_synchronizer.rb#L48).

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


*Known issues:*
- Pulling from non-prod results in thresholds file being incorrect. Be careful here, because this is almost by design. If thresholds vary across envionments, a design decision was made to use production as default values, and allow other environments to override as necessary. This is problematic when it's equal across environments. WIP to be smarter about how to handle. Right now, it will just produce broken threshold files if pulling from non-prod.
- If there are no thresholds defined, it will break again. Just remove the thresholds file.


## Generating fake data to test metrics

Use `rake <env>:emit[some.metric.name]` and follow the command line prompts.
Be careful, as this data may trigger false alarms, so be mindful of what you
are doing.

