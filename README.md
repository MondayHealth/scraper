# Scraper

The Scraper is a microservice to scrape content from individual pages and store provider data pulled from them.

Its background jobs pull down JSON or HTML from SSDB, then run them through parsers that output lines to a CSV file named after the payor or directory the data came from.

## Before You Start

You'll need to create a `.env` file in the root directory with the [environment variables](#environment-variables) and then source them:

    source .env

## Rake Tasks for Loading Providers

These can be run once the scrapers have finished outputting to CSV.

    bundle exec rake payors:load
    bundle exec rake directories:load

## Deploys

    New versions of the app are deployed by pushing to a remote dokku repository. 

### Set up the remote repository

    git remote add dokku dokku@monday-scraper:monday-scraper

### Deploy the master branch of the app

    git push dokku master

### Deploying another branch of the app

    git push dokku branch-name:master


## Environment Variables

`QUEUE`: Controls Resque background jobs, and should always be `scraper_*` to match the queues in the job classes for this repo.

`REDIS_HOST`, `REDIS_PORT`, and `REDIS_PASS`: Used by Resque to connect to the Redis server.

`SSDB_HOST`, `SSDB_PORT`, `SSDB_PASS`: Used by the crawler jobs to connect to the SSDB server.

`DATABASE_URL`: Used by ActiveRecord to connect to the Postgres server.

`PRIVATE_GEM_OAUTH_TOKEN`: A Github x-oauth token used by Gemfile to pull private core repository with shared models, and passed to Docker with a custom build argument on deploy. 

To generate your own token, visit [this page](https://github.com/settings/tokens) and click "Generate new token".

If you need to set up the private repository token on a fresh server, run the following from the root folder after setting the environment variable: 

    dokku docker-options:add monday-scraper build '--build-arg private_gem_oauth_token=$PRIVATE_GEM_OAUTH_TOKEN'
