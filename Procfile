web: bundle exec resque-web -p 5000 -L -F
worker: QUEUE=* rake environment resque:work