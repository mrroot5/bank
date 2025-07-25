echo "Starting credo...\n"
docker compose exec web mix credo --strict
echo "Starting recode suggestions....\n"
docker compose exec web mix recode
echo "\nApply recode suggestions with make recode\n"
echo "Starting dialyzer plt...\n"
docker compose exec web mix dialyzer --plt
echo "Starting dialyzer...\n"
docker compose exec web mix dialyzer --quiet-with-result
echo "\nTasks finished"
