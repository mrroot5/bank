.PHONY: iex

iex:
	@docker compose exec web sh -c 'iex --cookie web --sname console --remsh web_$$(hostname)@$$(hostname)'

bash:
	@docker exec -it bank-web-1 /bin/bash