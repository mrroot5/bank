.PHONY: iex bash

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
$(eval $(ARGS):;@:)

iex:
	@docker compose exec web sh -c 'iex --cookie web --sname console --remsh web_$$(hostname)@$$(hostname)'

bash:
	@docker exec -it bank-web-1 /bin/bash

tests:
	@docker compose -f docker-compose-test.yml run --rm web_test mix test --warnings-as-errors $(ARGS)
