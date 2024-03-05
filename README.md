# kong plugin: Do a token exchange with the Bedrock 'API Consumer Auth'
The `bedrock-api-consumer-auth` Kong plugin does a token Exchange by calling the Bedrock API Consumer Auth'. It works for Kong EE and Konnect.

## How deploy the `bedrock-api-consumer-auth` Kong plugin in KIC (Kong Ingress Controller)
1) Git clone this repository
```sh
git clone https://github.com/jeromeguillaume/kong-plugin-bedrock-api-consumer-auth.git
```
1) Create a ConfigMap
```sh
cd ./kong/plugins
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
- Change the config properties: Basic AuthN (`basic_auth_user`, `basic_auth_password`) and the URI of Bedrock API (`uri_environment` and `uri_tenant`)
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

## `bedrock-api-consumer-auth` configuration reference
|FORM PARAMETER                 |DEFAULT          |DESCRIPTION                                                                                                           |
|:------------------------------|:----------------|:---------------------------------------------------------------------------------------------------------------------|
|config.basic_auth_user         | N/A             |`Basic Auth` User name for calling Bedrock API Consumer Auth                                                          |
|config.basic_auth_password     | N/A             |`Basic Auth` Passwor for calling Bedrock API Consumer Auth                                                            |
|config.customercode_header_name|x-customer-code  |Header name for passing Customer Code                                                                                 |
|config.debug_mode              |false            |If `true` add debug message in the kong log and in the Consumer's error message                                       |
|ssl_verify                     |false            |If `true` verify the Bedrock API certificate and add the certificate in the `lua_ssl_trusted_certificate` Kong setting|
|uri_environment                |api-consumer-auth|Bedrock API Environment                                                                                               |
|uri_tenant                     |bedrock.tech     |Bedrock API Tenant                                                                                                    |