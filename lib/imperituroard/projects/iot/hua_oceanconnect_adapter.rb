require 'uri'
require 'net/http'
require 'net/https'
require 'json'
require 'rubygems'
require 'nokogiri'
require 'rails'


class HuaIot

  attr_accessor :platformip, :platformport, :client, :database, :cert_file, :key_file

  def initialize(platformip, platformport, iotip, database, cert_file, key_file)
    @database = database
    @platformip = platformip
    @platformport = platformport
    @iotip = iotip
    @cert_file = cert_file
    @key_file = key_file
    #client_host = [mongoip + ":" + mongoport]
    #@client = Mongo::Client.new(client_host, :database => database)
  end

  def parse_token(str)
    begin
      dd = str.split(",")
      acc_token = ""
      refr_token = ""
      exp_in = ""

      access_token = /\"accessToken\":\"(\S+)\"/
      refresh_token = /\"refreshToken\":\"(.+)\"/
      expires_in = /\"expiresIn\":(\d+)/

      for i in dd
        if i.to_s.include?("accessToken")
          acc_token = access_token.match(i)
        elsif i.to_s.include?("refreshToken")
          refr_token = refresh_token.match(i)
        elsif i.to_s.include?("expiresIn")
          exp_in = expires_in.match(i)
        end
      end
      {:status => 200, :result => "OK", :accessToken => acc_token[1], :refreshToken => refr_token[1], :expiresIn => exp_in[1]}
    rescue
      {:status => 500, :result => "failed"}
    end
  end

  def get_token(app_id, secret)
    path = "/iocm/app/sec/v1.1.0/login"
    url_string = "https://" + platformip + ":" + platformport + path
    uri = URI.parse url_string
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
    https.key = OpenSSL::PKey::RSA.new(File.read(key_file))
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.path)
    data = {
        :appId => app_id,
        :secret => secret
    }
    request.content_type = 'application/x-www-form-urlencoded'
    request.body = URI.encode_www_form(data)
    res = https.request(request)
    {:code => res.code, :message => res.message, :body => JSON.parse(res.body.to_s)}
  end

  #Registering a Directly Connected Device (Verification Code Mode) (V2)
  def dev_register_verif_code_mode(app_id, secret, node_id)
    token = get_token(app_id, secret)[:body]["accessToken"]
    path = "/iocm/app/reg/v1.1.0/deviceCredentials?appId=" + app_id
    url_string = "https://" + platformip + ":" + platformport + path
    uri = URI.parse url_string
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
    https.key = OpenSSL::PKey::RSA.new(File.read(key_file))
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.path)
    request.content_type = 'application/json'
    request['Authorization'] = 'Bearer ' + token
    request['app_key'] = app_id
    request.body = {nodeId: node_id}.to_json
    res = https.request(request)
    p res.body.to_s
    {:code => res.code, :message => res.message, :body => JSON.parse(res.body.to_s)}
  end


  def dev_delete(app_id, secret, node_id)
    token = get_token(app_id, secret)[:body]["accessToken"]
    path = "/iocm/app/dm/v1.1.0/devices/" + node_id + "?app_Id=" + app_id + "&cascade=true"
    url_string = "https://" + platformip + ":" + platformport + path
    uri = URI.parse url_string
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
    https.key = OpenSSL::PKey::RSA.new(File.read(key_file))
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Delete.new(uri.path)
    request.content_type = 'application/json'
    request['Authorization'] = 'Bearer ' + token
    request['app_key'] = app_id
    res = https.request(request)
    {:code => res.code, :message => res.message, :body => JSON.parse(res.body.to_s)}
  end


  #2.2.44 Querying the Device ID
  def querying_device_id(app_id, secret, node_id)
    token = get_token(app_id, secret)[:body]["accessToken"]
    path = "/iocm/app/dm/v1.1.0/queryDeviceIdByNodeId?nodeId=" + node_id
    p path
    p path
    url_string = "https://" + platformip + ":" + platformport + path
    p url_string
    uri = URI.parse url_string
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
    https.key = OpenSSL::PKey::RSA.new(File.read(key_file))
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.path)
    request.content_type = 'application/json'
    request['Authorization'] = 'Bearer ' + token
    request['app_key'] = app_id
    p request.body
    res = https.request(request)
    p res.body.to_s
    {:code => res.code, :message => res.message, :body => JSON.parse(res.body.to_s)}
  end

  #2.2.14 Querying Device Activation Status
  def querying_device_activ_status(app_id, secret, device_id)
    token = get_token(app_id, secret)[:body]["accessToken"]
    path = "/iocm/app/reg/v1.1.0/devices/" + device_id + "?app_Id=" + app_id
    url_string = "https://" + platformip + ":" + platformport + path
    uri = URI.parse url_string
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
    https.key = OpenSSL::PKey::RSA.new(File.read(key_file))
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.path)
    request.content_type = 'application/json'
    request['Authorization'] = 'Bearer ' + token
    request['app_key'] = app_id
    res = https.request(request)
    {:code => res.code, :message => res.message, :body => JSON.parse(res.body.to_s)}
  end


  #2.9.1 Querying Information About a Device
  def querying_device_info(app_id, secret, device_id)
    token = get_token(app_id, secret)[:body]["accessToken"]
    path = "/iocm/app/dm/v1.1.0/devices/" + device_id + "?app_Id=" + app_id
    url_string = "https://" + platformip + ":" + platformport + path
    uri = URI.parse url_string
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
    https.key = OpenSSL::PKey::RSA.new(File.read(key_file))
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.path)
    request.content_type = 'application/json'
    request['Authorization'] = 'Bearer ' + token
    request['app_key'] = app_id
    res = https.request(request)
    {:code => res.code, :message => res.message, :body => JSON.parse(res.body.to_s)}
  end

  #2.9.6 Querying Directly Connected Devices and Their Mounted Devices in Batches
  def querying_device_direct_conn(app_id, secret, dev_list)
    token = get_token(app_id, secret)[:body]["accessToken"]
    path = "/iocm/app/dm/v1.1.0/queryDevicesByIds"
    url_string = "https://" + platformip + ":" + platformport + path
    uri = URI.parse url_string
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
    https.key = OpenSSL::PKey::RSA.new(File.read(key_file))
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.path)
    request.content_type = 'application/json'
    request['Authorization'] = 'Bearer ' + token
    request['app_key'] = app_id
    request.body = {deviceIds: dev_list}.to_json
    res = https.request(request)
    {:code => res.code, :message => res.message, :body => JSON.parse(res.body.to_s)}
  end


  #2.9.19 Querying the Complete Device Type List of All Device Capabilities
  def querying_device_type_list(app_id, secret)
    token = get_token(app_id, secret)[:body]["accessToken"]
    path = "/iocm/app/profile/v1.1.0/allDeviceTypes"
    url_string = "https://" + platformip + ":" + platformport + path
    uri = URI.parse url_string
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
    https.key = OpenSSL::PKey::RSA.new(File.read(key_file))
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.path)
    request.content_type = 'application/json'
    request['Authorization'] = 'Bearer ' + token
    request['app_key'] = app_id
    res = https.request(request)
    {:code => res.code, :message => res.message, :body => JSON.parse(res.body.to_s)}
  end

  def test()

    url_string = "https://134.17.93.4:8743/iocm/app/sec/v1.1.0/login"
    headers = {
        'Authorization' => 'Bearer ppeMsOq6zdb2fSUH4GoRooS_FgEa',
        'Content-Type' => 'application/json',
        'Accept' => 'application/json'
    }

    req = {"dstAppId": "bCRahH5zSi9SNmyfqv3BkJABAq8a"}
    post_data = URI.encode_www_form(req)

    uri = URI.parse url_string

    p uri.host
    p uri.port
    p uri.path


    cert_file = "/Users/imperituroard/Desktop/cert.crt"
    key_file = "/Users/imperituroard/Desktop/key.pem"

    p https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    https.cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
    https.key = OpenSSL::PKey::RSA.new(File.read(key_file))
    https.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri.path)

    data = {
        :appId => "bCRahH5zSi9SNmyfqv3BkJABAq8a",
        :secret => "ppeMsOq6zdb2fSUH4GoRooS_FgEa"
    }


    #request['app_key'] = 'ppeMsOq6zdb2fSUH4GoRooS_FgEa'
    #request['Authorization'] = 'Bearer ppeMsOq6zdb2fSUH4GoRooS_FgEa'
    request.content_type = 'application/x-www-form-urlencoded'
    #p request.body = req
    request.body = URI.encode_www_form(data)
    res = https.request(request)
    p res.code
    p res.message

    p parse_token(res.body)

  end

  # App ID
  # password  O2k2aMStOweZOeSoVDYjI3c6uaMa


end