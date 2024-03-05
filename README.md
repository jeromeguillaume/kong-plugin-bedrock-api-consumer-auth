# kong plugin: token exchange Bedrock 'API Consumer Auth'
Kong plugin `bedrock-api-consumer-auth` does a token Exchange with the Bedrock 'API Consumer Auth'

## How deploy the `bedrock-api-consumer-auth` Kong plugin
1) Git clone this repository
```sh
git clone https://github.com/jeromeguillaume/kong-plugin-bedrock-api-consumer-auth.git
```
1) Create a ConfigMap
```sh
cd ./kong/plugins/bedrock-api-consumer-auth
kubectl create configmap create configmap bedrock-api-consumer-auth --from-file=./bedrock-api-consumer-auth
```
2) Re-deploy the Kong Gateway with Helm and the `bedrock-api-consumer-auth` Kong plugin
- Include the following parameters in the Helm values.yaml:
```yaml
gateway:
  image:
    repository: kong/kong-gateway
    tag: "3.5"
  ...  
  plugins:
    configMaps:
    - pluginName: bedrock-api-consumer-auth
      name: bedrock-api-consumer-auth
    ...
```
- Execute the Helm re-deployment:
```sh
helm upgrade kong kong/ingress -f ./values.yaml
```
4) Create a `bedrock-api-consumer-auth` KongPlugin
- Check the config properties: Basic AuthN(`basic_auth_user`, `basic_auth_password`) and the URI of Bedrock API (`uri_environment` and `uri_tenant`)
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
5) Add the `nonprod-bedrock-api-consumer-auth` Kong Plugin on the Service
```yaml
 annotations:
   ...
   konghq.com/plugins: nonprod-bedrock-api-consumer-auth
```