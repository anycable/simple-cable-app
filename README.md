# Simple Cable

Minimal ActionCable/AnyCable application which could be deployed on Heroku...

**UPD (2018-10):** ...And also a playground for performance experiments.

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

## Application Servers

This app could be served by different Ruby app servers:
- [Puma](https://github.com/puma/puma): `bundle exec puma -e production -w 4 -p 8080` (assuming you have 4 cores)
- [Falcon](https://github.com/socketry/falcon): `RAILS_ENV=production bundle exec falcon serve -b http://0.0.0.0:8080`
- [Iodine](https://github.com/boazsegev/iodine): `RAILS_ENV=production bundle exec falcon serve -b http://0.0.0.0:8080` ([this PR's](https://github.com/rails/rails/pull/33295) code is required)

## Heap capturing

- Run server with `DUMP=1`
- Connect to a server passing `?dump=1` param (e.g. using [ACLI](https://github.com/palkan/acli): `acli -u "ws://localhost:8080/cable?dump"`) to dump the current `ObjectSpace` into a file (`heap.json`)
- Run `ruby heapme.rb` to generate a `heap.png` (like the one below)

![](./heap.png)
