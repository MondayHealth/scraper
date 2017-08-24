web: bundle exec resque-web -p 8282 -L -F
worker: QUEUE=* rake environment resque:work