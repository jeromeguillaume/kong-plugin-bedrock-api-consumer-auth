-- handler.lua
local plugin = {
    PRIORITY = 700,
    VERSION = "0.1",
  }

-----------------------------------------------------------------------------------------------
-- Add entries in the kong log pod
-----------------------------------------------------------------------------------------------
local function custom_debug_log (debug_mode, debug_msg)
  if debug_mode then
    kong.log.notice(debug_msg)
  else
    kong.log.debug(debug_msg)
  end
end

-----------------------------------------------------------------------------------------------
-- Get Payload from an Authorization Token (JWT)
-- The JWT has 3 parts, separated by a dot: Header.Payload.Signature
-----------------------------------------------------------------------------------------------
local function get_payload_JWT (jwt_auth_token_json)
  local jwt_payload
  local utils = require "kong.tools.utils"
  local entries = utils.split(jwt_auth_token_json, ".")

  if #entries == 3 then
    jwt_payload = entries[2]
  else
    local err = "Inconsistent JWT: unable to get the typical structure Header.Payload.Signature"
    return nil, err
  end

  -- bas64 decoding of JWT payload
  local decode_base64 = ngx.decode_base64
  local decoded = decode_base64(jwt_payload)
  local cjson = require("cjson.safe").new()
  local jwt_auth_token_json, err = cjson.decode(decoded)
  -- If we failed to base64 decode
  if err then
    err = "Unable to decode JSON from JWT: '" .. err .. "'"
    return nil, err
  end

  return jwt_auth_token_json, nil
end

-----------------------------------------------------------------------------------------------
-- Call the Bedrock API Consumer Auth
-- Get a JWT by sending a CustomerCode
-----------------------------------------------------------------------------------------------
local function Bedrock_apiConsumerAuth(plugin_conf, customerCode)
  local errMsg = {}
  local logDetail
  local bedrockEndpointURL
  local body_json
  local jwt_auth_token_json
  local debug_msg
  
  local http = require "resty.http"
  local httpc = http.new()
  
  bedrockEndpointURL = "https://" .. plugin_conf.uri_environment .. "." .. plugin_conf.uri_tenant .. "/api/" .. customerCode .. "/token"

  -- bas64 encoding
  local encode_base64 = ngx.encode_base64
  local encoded_base64 = encode_base64(plugin_conf.basic_auth_user .. ':' .. plugin_conf.basic_auth_password)
  
  custom_debug_log(plugin_conf.debug_mode, "Send HTTP request to: '" .. bedrockEndpointURL .. "' Authorization: Basic " .. encoded_base64)

  local res, err = httpc:request_uri(bedrockEndpointURL, { 
      method = "POST",
      headers = {
          ["Content-Type"] = "application/json",
          ["Authorization"] = "Basic " .. encoded_base64
      },
      query = {},
      body = {},
      keepalive_timeout = 60,
      keepalive_pool = 10,
      ssl_verify = plugin_conf.ssl_verify
      })
  if err then
    errMsg.code   = "INTERNAL_TOKEN_EXCHANGE_FAILURE"
    errMsg.error  = "Unauthorized, unable to call 'API Consumer Auth' (token exchange service)"
    logDetail     = "customer='" .. customerCode .. "', Error from='" .. bedrockEndpointURL .. ", err='".. err .. "'"
    if plugin_conf.debug_mode then errMsg.error_detail=logDetail end
    kong.log.err(errMsg.code .. ", " .. errMsg.error .. ", " .. logDetail)
    return kong.response.exit(401, errMsg,  {["Content-Type"] = "application/json"})
  end

  custom_debug_log(plugin_conf.debug_mode, "Response from API server: '" .. bedrockEndpointURL .. "' body: '" .. res.body .. "'")
  
  -- Successful response - 200 Ok
  -- { 
  --   "token": "string",
  --   "refreshToken": "string"
  -- }
  --
  -- Failed response - 4XX or 5XX
  -- {
  --   "message": "string"
  -- }

  -- If there is no HTTP Error
  if res.status == 200 then
    local cjson = require("cjson.safe").new()
    body_json, err = cjson.decode(res.body)
    -- If we failed to JSON decode the Body
    if err then
      kong.log.err ( "Failure to JSON decode the body response")
    end
  end

  -- If there is a valid JSON Body with a token property
  if body_json and body_json.token then
    -- Check the 'validity' of the JWT at high level: 
    --     Having 3 parts (Header.Payload.Signature) 
    --      + 
    --     Having a consistent JSON payload
    jwt_auth_token_json, err = get_payload_JWT (body_json.token)
    if err then
      kong.log.err("Unable to decode the JWT into a JSON object, err: '" .. err .. "'")
    end
  end

  -- If there is no valid JWT token
  if not jwt_auth_token_json  then
    errMsg.code   = "TOKEN_EXCHANGE_FAILURE"
    errMsg.error  = "Unauthorized, unable to call 'API Consumer Auth' (token exchange service)"
    local bodyLog = res.body or "No body response"
    logDetail     = "customer='" .. customerCode .. "', Error from='".. bedrockEndpointURL .. "', httpStatus=" .. res.status .. ", Response Body='" .. bodyLog .. "'"
    
    kong.log.err(errMsg.code .. ", " .. errMsg.error .. ", " .. logDetail)
    if plugin_conf.debug_mode then errMsg.error_detail=logDetail end
    return kong.response.exit(401, errMsg,  {["Content-Type"] = "application/json"})
  end
  
  return body_json.token
  
end

---------------------------------------------------------------------------------------------------
-- Executed for every request from a client and before it is being proxied to the upstream service
---------------------------------------------------------------------------------------------------
function plugin:access(plugin_conf)
  
  local utils = require "kong.tools.utils"
  local errMsg = {}
  local logDetail
  local entries
  local jwt_auth_token
  local jwt_auth_token_json
  local new_jwt_auth_token
  local err

  local customerCode         = kong.request.get_header(plugin_conf.customercode_header_name)
  local authorization_header = kong.request.get_header("Authorization")
  
  -- If the 'customerCode' Header is found
  if customerCode then
    custom_debug_log(plugin_conf.debug_mode, "Customer Code retrieved successfully from Header: '" .. customerCode .. "'")

  -- If the 'Authorization' Header is found
  elseif authorization_header then
    -- Try to find an 'Authorization: Bearer'
    entries = utils.split(authorization_header, "Bearer ")
    if #entries == 2 then
      jwt_auth_token = entries[2]
      custom_debug_log(plugin_conf.debug_mode, "'Authentication Bearer' Token retrieved successfully")
      
      -- Decode the JWT into a JSON object
      jwt_auth_token_json, err = get_payload_JWT (jwt_auth_token)
      if err then
        logDetail = "Unable to decode the JWT into a JSON object, err: '" .. err .. "'"
        kong.log.err(logDetail)
      -- If the 'customer' claim is found
      elseif jwt_auth_token_json.customer then
        customerCode = jwt_auth_token_json.customer        
        custom_debug_log(plugin_conf.debug_mode, "Customer Code retrieved successfully from JWT claim: '" .. customerCode .. "'")
      else
        logDetail = "Unable to find 'customer' clain in the JWT"
        kong.log.err(logDetail)
      end
    else
      logDetail = "There is no 'Authorization: Bearer' header"
      kong.log.err(logDetail)
    end
  else
    logDetail = "There is neither 'customerCode' Header nor 'Authorization' header"
    kong.log.err(logDetail)
  end

  -- If the Customer Code isn't found
  if not customerCode then
    errMsg.error = "Unauthorized, unable to find the 'Customer Code' value"
    errMsg.code = "INVALID_CUSTOMER_CODE"
    kong.log.err(errMsg.code .. ", " .. errMsg.error)
    if plugin_conf.debug_mode then errMsg.error_detail=logDetail end
    return kong.response.exit(401, errMsg,  {["Content-Type"] = "application/json"})
  end
  
  -- Call the Bedrock API Consumer Auth
  local new_jwt_auth_token = Bedrock_apiConsumerAuth(plugin_conf, customerCode)
  
  custom_debug_log(plugin_conf.debug_mode, "Retrieved successfully the new Authorization Token from 'API Consumer Auth'")  

  kong.service.request.set_header("Authorization", "Bearer " .. new_jwt_auth_token)

end

return plugin