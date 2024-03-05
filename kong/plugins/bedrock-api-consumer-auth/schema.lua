local typedefs = require "kong.db.schema.typedefs"

return {
  name = "bedrock-api-consumer-auth",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { basic_auth_user = { type = "string", required = true }, },
          { basic_auth_password = { type = "string", required = true }, },
          { customercode_header_name = { type = "string", required = false, default="x-customer-code"}, },
          { debug_mode = { type = "boolean", required = false, default=false}, },
          { ssl_verify = { type = "boolean", required = false, default=false}, },
          { uri_environment = { type = "string", required = true, default="api-consumer-auth"}, },
          { uri_tenant = { type = "string", required = true, default="bedrock.tech"}, },
        },
    }, },
  },
}