FROM ruby:2.4

ARG private_gem_oauth_token

USER root

RUN apt-get update

RUN apt-get install -y postgresql postgresql-contrib

WORKDIR /app
COPY . ./

ENV PRIVATE_GEM_OAUTH_TOKEN $private_gem_oauth_token
ENV PATH="/app/storage/vendor/bundle/bin:$PATH"

RUN PRIVATE_GEM_OAUTH_TOKEN=$PRIVATE_GEM_OAUTH_TOKEN bundle install --path /app/storage/vendor/bundle --binstubs /app/storage/vendor/bundle/bin 