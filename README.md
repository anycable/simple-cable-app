# Simple Cable

Minimal ActionCable/AnyCable application which could be deployed on Heroku.

## Deployment

```sh
# Create app
heroku create simple-cable-app

# We need Redis for pub/sub
heroku addons:create heroku-redis

# Configure buildpacks
heroku buildpacks:add https://github.com/anycable/heroku-anycable-go
heroku buildpacks:add heroku/ruby

heroku config:set ANYCABLE_DEPLOYMENT=true

# (optionally) Use anycable-go with mruby support
# and log stats in Librato format
heroku config:set HEROKU_ANYCABLE_GO_VERSION=0.6.0-mrb
heroku config:set ANYCABLE_METRICS_LOG_FORMATTER=etc/anycable_librato_logger.rb

git push heroku master
```

## Integration Tests

You can use [wsdirector](https://github.com/palkan/wsdirector) to verify your deployment:

```sh
wsdirector features/broadcast.yml wss://simple-cable-app.herokuapp.com/cable -s 10
```

See `features/` folder for available scenarios.
