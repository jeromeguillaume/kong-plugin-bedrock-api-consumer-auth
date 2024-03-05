# kong plugin: Do a token exchange with the Bedrock - API Consumer Auth
The `bedrock-api-consumer-auth` Kong plugin does a token Exchange by calling the Bedrock - API Consumer Auth. It works for Kong EE and Konnect.

## How deploy the `bedrock-api-consumer-auth` Kong plugin in KIC (Kong Ingress Controller)
1) Git clone this repository
```sh
git clone https://github.com/jeromeguillaume/kong-plugin-bedrock-api-consumer-auth.git
```
1) Create a ConfigMap
```sh
cd ./kong-plugin-bedrock-api-consumer-auth/kong/plugins
kubectl -n kong create configmap bedrock-api-consumer-auth --from-file=./bedrock-api-consumer-auth
```
2) Re-deploy the Kong Gateway by using Helm and configure the Chart with the `bedrock-api-consumer-auth` Kong plugin and the `untrusted_lua_sandbox_requires`
- Include the following parameters in the Helm values.yaml:
```yaml
gateway:
  image:
    repository: kong/kong-gateway
  ...  
  env:
    ...
    untrusted_lua_sandbox_requires: resty.http,cjson.safe,kong.tools.utils
  plugins:
    configMaps:
    - pluginName: bedrock-api-consumer-auth
      name: bedrock-api-consumer-auth
    ...
```
- Execute the Helm deployment:
  - Install or Upgrade
```sh
helm -n kong install kong kong/ingress -f ./values.yaml
```
```sh
helm -n kong upgrade kong kong/ingress -f ./values.yaml
```
4) Create a `bedrock-api-consumer-auth` KongPlugin
- Change the config properties: Basic AuthN (`basic_auth_user`, `basic_auth_password`) and the URI of Bedrock - API (`uri_environment` and `uri_tenant`)
```yaml
 apiVersion: configuration.konghq.com/v1
 kind: KongPlugin
 metadata:
   name: nonprod-bedrock-api-consumer-auth
   annotations:
     kubernetes.io/ingress.class: kong
 plugin: bedrock-api-consumer-auth
 config:
   basic_auth_user: mysuser
   basic_auth_password: mypassword
   uri_environment: api-consumer-auth
   uri_tenant: bedrock.tech
```
5) Add `nonprod-bedrock-api-consumer-auth` Kong Plugin to the Service
```yaml
 annotations:
   ...
   konghq.com/plugins: nonprod-bedrock-api-consumer-auth
```

## How test the `bedrock-api-consumer-auth` Kong plugin
Access to the Service (defined at step #5, see above) through the Kong Gateway:
- Use the `x-customer-code` Header for sending the Customer Code
```sh
curl -i https://kong-gateway.bedrock.com:443/myservice -H x-customer-code:bedrock
```
```sh
HTTP/2 200 
content-type: application/json
Server: kong/3.5.0.3-enterprise-edition
...
```
- Use the `Authorization Bearer` Header for sending the Customer Code in a JWT (having a `customer` claim)
```sh
curl -i https://kong-gateway.bedrock.com:443/myservice -H 'Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJxOEVFR3YweE9FQkt3eFNJYVZDNGpHTWxVcF8yWURhS1pfMVdZNHV3b2lRIn0.eyJleHAiOjE3MDk2NDcxNjksImlhdCI6MTcwOTY0Njg2OSwianRpIjoiMDI1YzQwMTItZDgxZS00M2I5LWFmNTQtODU5NmZlYmJkYThkIiwiaXNzIjoiaHR0cHM6Ly9zc28uYXBpbS5ldTo4NDQzL2F1dGgvcmVhbG1zL0plcm9tZSIsImF1ZCI6ImFjY291bnQiLCJzdWIiOiI4YTc2OTAwOS0wYjUwLTRlN2UtOWM1Yi1jNWE0NTQ2ZjhmNzciLCJ0eXAiOiJCZWFyZXIiLCJhenAiOiJrb25nIiwic2Vzc2lvbl9zdGF0ZSI6ImY0ZWExNDhhLWJlZDYtNDI5Yy04NmYyLTMzZDJlNGY4MTIwNiIsImFjciI6IjEiLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsib2ZmbGluZV9hY2Nlc3MiLCJkZWZhdWx0LXJvbGVzLWplcm9tZSIsInVtYV9hdXRob3JpemF0aW9uIl19LCJyZXNvdXJjZV9hY2Nlc3MiOnsiYWNjb3VudCI6eyJyb2xlcyI6WyJtYW5hZ2UtYWNjb3VudCIsIm1hbmFnZS1hY2NvdW50LWxpbmtzIiwidmlldy1wcm9maWxlIl19fSwic2NvcGUiOiJvcGVuaWQgZW1haWwgcHJvZmlsZSIsInNpZCI6ImY0ZWExNDhhLWJlZDYtNDI5Yy04NmYyLTMzZDJlNGY4MTIwNiIsInNlcnZlciI6InNlcnZlckEiLCJteWdyb3VwIjoiZ3JvdXB3ZWIiLCJlbWFpbF92ZXJpZmllZCI6ZmFsc2UsInByZWZlcnJlZF91c2VybmFtZSI6InVzZXIxIiwic2VydmVyMiI6InNlcnZlckItMSIsImN1c3RvbWVyIjoiYmVkcm9jayJ9.UTysno19PJyWZvlTKZTUtCtrf-W_MedtmYE3uRYJK6u7g9H4B_Q825CLht6SbqlRvYZfcWf3pgIXEnjoaVeZUL6Fzus-iKpzOqaA6RzxwyLbiptCptd6X5wUKOfEIghzc57mF4SdrojXV3n4bzHXyHUNLymHDMKmJEoaZap6PIE1LWLEo34-ilQZGhEUcYcUF_PBH55sYf3Sp0-CXMYA5tg5wLKrl5wilHVY4_payvleLQh5Pcqw9dLT_H86eZvzAcbd7-zHrwbI6tuO7FS0STxYWO_Exezjq-7DwF8fdr96Bk0HdXaVHH0PDICmwfqKw8GQ841kd9V2N71UwLwV7A'
```
```sh
HTTP/2 200 
content-type: application/json
Server: kong/3.5.0.3-enterprise-edition
...
```
- In case of error (wrong Customer Code, Invalid call of the Bedrock - API Consumer Auth, etc.) the `bedrock-api-consumer-auth` Kong plugin sends a `401` Error, for instance:
```
HTTP/2 401 Unauthorized
Content-Type: application/json
Server: kong/3.5.0.3-enterprise-edition
...
{
    "code": "TOKEN_EXCHANGE_FAILURE",
    "error": "Unauthorized, unable to call 'API Consumer Auth' (token exchange service)"
}
```

## `bedrock-api-consumer-auth` configuration reference
|FORM PARAMETER                 |DEFAULT          |DESCRIPTION                                                 |
|:------------------------------|:----------------|:-----------------------------------------------------------|
|config.basic_auth_user         |N/A              |`Basic Auth` User name for calling Bedrock - API Consumer Auth|
|config.basic_auth_password     |N/A              |`Basic Auth` Password for calling Bedrock - API Consumer Auth|
|config.customercode_header_name|x-customer-code  |Header name for passing Customer Code. If the Consumer doesn't provide it, the `Àuthorization Bearer` is retrieved and the plugin looks for `consumer` claim|
|config.debug_mode              |false            |If `true` add debug message in the kong log and in the Consumer's error message|
|config.ssl_verify              |false            |If `true` verify the Bedrock - API Consumer Auth certificate and please add the certificate in the `lua_ssl_trusted_certificate` Kong setting|
|config.uri_environment         |api-consumer-auth|The URI of Bedrock - API Consumer Auth is [https://uri_environment.uri_tenant](https://uri_environment.uri_tenant)|
|config.uri_tenant              |bedrock.tech     |The URI of Bedrock - API Consumer Auth is [https://uri_environment.uri_tenant](https://uri_environment.uri_tenant)|