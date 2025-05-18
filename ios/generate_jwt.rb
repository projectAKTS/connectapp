require 'jwt'

key = OpenSSL::PKey::EC.new(File.read('/tmp/AuthKey.p8'))
team_id = ENV['TESTFLIGHT_API_ISSUER_ID']
key_id = ENV['TESTFLIGHT_API_KEY_ID']

token = JWT.encode(
  {
    iss: team_id,
    exp: Time.now.to_i + 20 * 60,
    aud: "appstoreconnect-v1"
  },
  key,
  'ES256',
  { kid: key_id }
)

puts token
