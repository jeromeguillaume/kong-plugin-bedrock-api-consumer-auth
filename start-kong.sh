# remove the previous container
docker rm -f kong-api-consumer-auth >/dev/null

docker run -d --name kong-api-consumer-auth \
--network=kong-net \
--mount type=bind,source="$(pwd)"/kong/plugins/bedrock-api-consumer-auth,destination=/usr/local/share/lua/5.1/kong/plugins/bedrock-api-consumer-auth \
--link kong-database-api-consumer-auth:kong-database-api-consumer-auth \
-e "KONG_DATABASE=postgres" \
-e "KONG_PG_HOST=kong-database-api-consumer-auth" \
-e "KONG_PG_USER=kong" \
-e "KONG_PG_PASSWORD=kongpass" \
-e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
-e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
-e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
-e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
-e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
-e "KONG_ADMIN_GUI_URL=http://localhost:8002" \
-e "KONG_PLUGINS=bundled,bedrock-api-consumer-auth" \
-e "KONG_REAL_IP_HEADER=X-Forwarded-For" \
-e "KONG_TRUSTED_IPS=0.0.0.0/0,::/0" \
-e "KONG_NGINX_WORKER_PROCESSES=1" \
-e KONG_LICENSE_DATA \
-p 8000:8000 \
-p 8443:8443 \
-p 8001:8001 \
-p 8002:8002 \
-p 8003:8003 \
-p 8004:8004 \
-p 8444:8444 \
kong/kong-gateway:3.5.0.3
#kong/kong-gateway:3.6.1.0




echo 'docker logs -f kong-api-consumer-auth'