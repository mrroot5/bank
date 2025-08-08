.PHONY: bash credo dialyzer iex logs-web recode restart-web rm start stop tests

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(ARGS):;@:)

bash:
	@docker compose exec web /bin/bash

ci:
	@make-scripts/ci.sh $(ARGS)

credo:
	@docker compose exec web mix credo --strict

dialyzer:
	@docker compose exec web mix dialyzer

iex:
	@docker compose exec web sh -c 'iex --cookie web --sname console --remsh web_$$(hostname)@$$(hostname)'

logs-web:
	@docker compose logs -f web

recode:
	docker compose exec web mix recode --no-dry

restart-web:
	@docker compose restart web

rm:
	@docker compose rm -f

start:
	@docker compose up -d

stop:
	@docker compose stop

tests:
	@docker compose -f docker-compose-test.yml run --rm web_test mix test --warnings-as-errors $(ARGS)
