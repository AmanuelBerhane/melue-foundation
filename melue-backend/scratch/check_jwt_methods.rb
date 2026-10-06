require "net/http"
require "json"

app = RodauthMain.allocate
puts "Ancestors with JWT: #{RodauthMain.ancestors.grep(/jwt/i)}"
puts "Instance methods with jwt: #{RodauthMain.instance_methods.grep(/jwt/i).sort}"
