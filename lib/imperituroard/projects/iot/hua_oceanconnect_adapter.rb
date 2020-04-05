require 'uri'
require 'net/http'
require 'net/https'
require 'json'


class HuaIot

  attr_accessor :platformip, :platformport, :client, :database

  def initialize(platformip, platformport, iotip, database)
    @database = database
    @platformip = platformip
    @platformport = platformport
    @iotip = iotip
    #client_host = [mongoip + ":" + mongoport]
    #@client = Mongo::Client.new(client_host, :database => database)
  end

  def test()

    url_string = "https://134.17.93.4:8743/iocm/app/authorize/v1.3.0/app"
    headers = {
        'Authorization'=>'Bearer O2k2aMStOweZOeSoVDYjI3c6uaMa',
        'Content-Type' =>'application/json',
        'Accept'=>'application/json'
    }

    req = {"dstAppId": "Cd1v0k2gTBCbpQlMVlW1FVqOSqga" }

    uri = URI.parse url_string

    p uri.host
    p uri.port
    p uri.path

    p  https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new( uri.path, headers)

    p request.body = req
    request['app_key'] = ''
    request['Authorization'] = 'Bearer O2k2aMStOweZOeSoVDYjI3c6uaMa'
    request.content_type = 'application/json'
    res = https.request(request)
    p res.message

  end

 # App ID
 # password  O2k2aMStOweZOeSoVDYjI3c6uaMa



end