# Simple Cable

Minimal ActionCable/AnyCable application which could be deployed on Heroku
and also a playground for performance experiments.

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
heroku config:set HEROKU_ANYCABLE_GO_VERSION=0.6.4-mrb
heroku config:set ANYCABLE_METRICS_LOG_FORMATTER=etc/anycable_librato_logger.rb

git push heroku master
```

## Integration Tests

You can use [wsdirector](https://github.com/palkan/wsdirector) to verify your deployment:

```sh
wsdirector features/broadcast.yml wss://simple-cable-app.herokuapp.com/cable -s 10
```

See `features/` folder for available scenarios.

## Benchmarking/testing

Use [websocket-bench](https://github.com/anycable/websocket-bench) for stress testing.
For example, to run `broadcast` scenario you use the predefined options:

```ruby
cat benchmarks/broadcast.opts | xargs websocket-bench broadcast
...
```

Use [ACLI](https://github.com/palkan/acli) to connect to Action Cable server from your terminal.

## Heap capturing

- Run server with `DUMP=1` (`DUMP=1 bundle exec puma -p 8080` or `DUMP=1 bundle exec anycable --server-command="anycable-go --port 8080" -r ./anycable.rb`)
- Do some stress (see `benchmarks/simulate.rb`)
- Connect to a server passing `?dump=1` param (e.g., using ACLI: `acli -u "ws://localhost:8080/cable?dump"`) to dump the current `ObjectSpace` into a file (`tmp/heap.json`)
- Run `ruby etc/heapme.rb tmp/heap.json` to generate a `heap.png` (like the one below)

![](./heap.png)
