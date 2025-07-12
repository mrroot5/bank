.PHONY: bash iex tests

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(ARGS):;@:)

bash:
	@docker compose exec web /bin/bash

ci:
	@make-scripts/ci.sh $(ARGS)

tests:
	@make-scripts/ci.sh $(ARGS)

iex:
	@docker compose exec web sh -c 'iex --cookie web --sname console --remsh web_$$(hostname)@$$(hostname)'

tests:
	@docker compose -f docker-compose-test.yml run --rm web_test mix test --warnings-as-errors $(ARGS)
