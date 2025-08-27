# Bank

The idea behind this project is based on my
[Python wallet project](https://github.com/mrroot5/django-atomic-transactions).

## Disclaimer

This is an example project. I'm not trying to create a real bank website.

Security, some audit requirements and features are simplified.

## Features

Transactions, withdraw, deposit, fees, exchange rate. Basically, a real bank.

I'm working on it so step by step. [Take a look on my PRs](https://github.com/mrroot5/bank/pulls?q=is%3Apr+Feature)
to see what is done and what is under development.

## Up & running

- Using make:

```shell
make start
```

- Just docker:

```shell
docker compose up -d
```

## Why I did the project this way?

Pleas check [whys](./whys/README.md) folder.

## Future

- [x] Contexts to manage money movements.
- [ ] Future transactions with Oban (periodic or future transactions).
- [ ] Views to manage money movements by users.
- [ ] Reports.
- [ ] Code quality / security analysis.
- [ ] Resellers / wholesale.
