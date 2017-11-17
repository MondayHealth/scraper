FROM ruby:2.4

ARG private_gem_oauth_token

USER root

RUN apt-get update

RUN apt-get install -y postgresql postgresql-contrib

ENV PRIVATE_GEM_OAUTH_TOKEN $private_gem_oauth_token

WORKDIR /tmp/gems
ADD Gemfile /tmp/gems/Gemfile
ADD Gemfile.lock /tmp/gems/Gemfile.lock
RUN bundle config github.com $PRIVATE_GEM_OAUTH_TOKEN:x-oauth-basic
RUN bundle install 

ADD . /app

WORKDIR /app