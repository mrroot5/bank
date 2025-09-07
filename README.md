# Bank

The idea behind this project is based on my
[Python wallet project](https://github.com/mrroot5/django-atomic-transactions).

## Disclaimer

This is an example project. I'm not trying to create a real bank website.

Security, some audit requirements and features are simplified.

## Features

Transactions, withdraw, deposit, fees, exchange rate...

I'm working on it so step by step.
Take a look the [feature type PRs](https://github.com/mrroot5/bank/pulls?q=is%3Apr+feature+in%3Atitle+) or
[refactors](https://github.com/mrroot5/bank/pulls?q=is%3Apr+refactor+in%3Atitle+). I also have others like:
bugfix, build, style, docs. Take a look to the list of labels :wink:.

## Up & running

- Using make:

```shell
make start
```

- Just docker:

```shell
docker compose up -d
```

Check it on: [http://localhost:4000](http://localhost:4000).

## Test it

- Using make:

```shell
make tests
```

- Just docker:

```shell
docker compose -f docker-compose-test.yml run --rm web_test mix test --warnings-as-errors
```

## Seed it

Inside the web container:

- Using make:

```shell
make bash
```

- Just docker:

```shell
docker compose exec web /bin/bash
```

Execute seed command:

```shell
mix run priv/repo/seeds.exs
```

## CI but locally

- Using make:

```shell
make ci
```

- Just docker:

Yo have all executed command in `make-scripts/ci.sh`.

## Why I did the project this way?

Pleas check [whys](./whys/README.md) folder.
