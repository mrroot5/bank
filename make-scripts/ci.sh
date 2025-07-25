echo "Starting format...\n"
docker compose exec web mix format
echo "\nStarting credo...\n"
docker compose exec web mix credo --strict
echo "\nStarting recode suggestions....\n"
docker compose exec web mix recode
echo "\nAPPLY RECODE SUGGESTIONS WITH: make recode\n"
echo "\nStarting dialyzer plt...\n"
docker compose exec web mix dialyzer --plt
echo "Starting dialyzer...\n"
docker compose exec web mix dialyzer --quiet-with-result
echo "\nTasks finished"
