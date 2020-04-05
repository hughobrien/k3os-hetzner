network = {
  vpc     = "10.0.0.0/16",
  host    = "10.0.0.0/24",
  pod     = "10.0.100.0/24",
  service = "10.0.200.0/24",
  zone    = "eu-central",
}

presence = [
  { "region" : "nuremberg", "code" : "nbg1", "count" : 3 },
  { "region" : "falkenstein", "code" : "fsn1", "count" : 0 },
  { "region" : "helsinki", "code" : "hel1", "count" : 0 },
]

# Also Consider
#presence = [
#  { "region" : "nuremberg", "code" : "nbg1", "count" : 1 },
#  { "region" : "falkenstein", "code" : "fsn1", "count" : 1 },
#  { "region" : "helsinki", "code" : "hel1", "count" : 1 },
#]

# Choose your server type
# Choices: cx[11|21|31|41|51]
default_server_type = "cx21"
