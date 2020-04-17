require 'uri'
require 'net/http'
require 'net/https'
require 'json'
require 'rubygems'
require 'nokogiri'
require 'rails'
require "imperituroard/projects/iot/internal_functions"


class HuaIot

  attr_accessor :platformip, :platformport, :client, :database, :cert_file, :key_file, :internal_func

  def initialize(platformip, platformport, cert_file, key_file)
    @database = database
    @platformip = platformip
    @platformport = platformport
    @cert_file = cert_file
    @key_file = key_file
    #client_host = [mongoip + ":" + mongoport]
    #@client = Mongo::Client.new(client_host, :database => database)
    @internal_func = InternalFunc.new
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
    internal_func.printer_texter("get_token: start. Step1, iput: app_id: #{app_id.to_s}, secret: #{secret.to_s}", "debug")
    out_resp = {}
    begin
      path = "/iocm/app/sec/v1.1.0/login"
      url_string = "https://" + platformip + ":" + platformport + path
      internal_func.printer_texter("get_token: start. Step2, url_string: #{url_string}", "debug")
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
      internal_func.printer_texter("get_token: start. Step3, data: #{data.to_s}", "debug")
      request.content_type = 'application/x-www-form-urlencoded'
      request.body = URI.encode_www_form(data)
      res = https.request(request)
      out_resp = {:code => res.code, :message => res.message, :body => JSON.parse(res.body.to_s)}
    rescue
      out_resp = {:code => 500, :message => "failed get token"}
    end
    jjj = {:procedure => "get_token", :answ => out_resp}
    internal_func.printer_texter(jjj, "debug")
    out_resp
  end


  def token_logout(token)

    internal_func.printer_texter("token_logout Step1 token: #{token}", "debug")
    out_resp = {}
    begin
      path = "/iocm/app/sec/v1.1.0/logout"
      url_string = "https://" + platformip + ":" + platformport + path
      internal_func.printer_texter("token_logout Step2 url_string: #{url_string}", "debug")
      uri = URI.parse url_string
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
      https.key = OpenSSL::PKey::RSA.new(File.read(key_file))
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Post.new(uri.path)
      data = {
          :accessToken => token
      }
      internal_func.printer_texter("token_logout Step3 data: #{data.to_s}", "debug")
      request.content_type = 'application/json'
      request.body = URI.encode_www_form(data)
      res = https.request(request)
      out_resp = {:code => res.code, :message => res.message, :body => JSON.parse(res.body.to_s)}
    rescue
      out_resp = {:code => 500, :message => "failed logout token"}
    end
    jjj = {:procedure => "token_logout", :answ => out_resp}
    internal_func.printer_texter(jjj, "debug")
    out_resp
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

  #2.2.4 Registering a Directly Connected Device (Password Mode) (V2)
  def dev_register_passw_code_mode2(app_id, secret, node_id, name_p, description_p, device_type, profile, manufacturer_id, manufacturer_name, model)
    out_resp = {}
    token = get_token(app_id, secret)[:body]["accessToken"]
    path = "/iocm/app/reg/v2.0.0/deviceCredentials?appId=" + app_id
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
    data_out = {deviceInfo: {nodeId: node_id,
                             name: name_p,
                             description: description_p,
                             deviceType: device_type,
                             manufacturerId: manufacturer_id,
                             manufacturerName: manufacturer_name,
                             model: model,
                             isSecurity: "FALSE",
                             supportedSecurity: "FALSE"}}.to_json
    internal_func.printer_texter({:procedure => "dev_register_passw_code_mode2", :data => {:body => data_out, :url => url_string}}, "debug")
    request.body = data_out
    res = https.request(request)
    p res.body.to_s
    out_resp = {:code => res.code, :message => res.message, :body => JSON.parse(res.body.to_s)}
    p out_resp
    out_resp
  end


  #2.2.4 Registering a Directly Connected Device (Password Mode) (V2)
  def dev_reg_passw_code_mode2_2(app_id, secret, attr_list)
    out_resp = {}
    token = get_token(app_id, secret)[:body]["accessToken"]
    path = "/iocm/app/reg/v2.0.0/deviceCredentials?appId=" + app_id
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
    data_out = {deviceInfo: attr_list}.to_json
    internal_func.printer_texter({:procedure => "dev_register_passw_code_mode2", :data => {:body => data_out, :url => url_string}}, "debug")
    request.body = data_out
    res = https.request(request)
    p res.body.to_s
    out_resp = {:code => res.code, :message => res.message, :body => JSON.parse(res.body.to_s)}
    p out_resp
    out_resp
  end


  #2.2.12 Deleting a Directly Connected Device
  def dev_delete(app_id, dev_id, token)
    out_resp = {}

    begin
      path = "/iocm/app/dm/v1.1.0/devices/" + dev_id + "?app_Id=" + app_id + "&cascade=true"
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
      p res.code
      p res.body
      if res.body != nil
        out_resp = {:code => res.code, :message => res.message, :body => {:answ => JSON.parse(res.body.to_s)}}
      else
        out_resp = {:code => res.code, :message => res.message, :body => {:answ => "no data"}}
      end
    rescue
      out_resp = {:code => 500, :message => "dev_delete: Unknown IOT error"}
    end
    p out_resp
    out_resp
  end


  #2.2.44 Querying the Device ID
  def querying_device_id(app_id, secret, node_id)
    token = get_token(app_id, secret)[:body]["accessToken"]
    p token
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
    res = https.request(request)
    p res.body.to_s
    p res.code
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


  #2.9.6 Querying Directly Connected Devices and Their Mounted Devices in Batches
  def quer_dev_direct_conn_batches(app_id, dev_list, token)

    path = "/iocm/app/dm/v1.1.0/queryDevicesByIds"
    url_string = "https://" + platformip + ":" + platformport + path
    p url_string
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


  #2.2.11 Modifying Device Information (V2)
  def dev_modify_location_v2(app_id, dev_id, token, address)
    out_resp = {}

    begin
      path = "/iocm/app/dm/v1.4.0/devices/" + dev_id + "?app_Id=" + app_id
      url_string = "https://" + platformip + ":" + platformport + path
      internal_func.printer_texter({:url_string=>url_string, :procedure=>"dev_modify_location_v2"}, "debug")
      uri = URI.parse url_string
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.cert = OpenSSL::X509::Certificate.new(File.read(cert_file))
      https.key = OpenSSL::PKey::RSA.new(File.read(key_file))
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Put.new(uri.path)
      request.content_type = 'application/json'
      request['Authorization'] = 'Bearer ' + token
      request['app_key'] = app_id
      request.body = {location: address}.to_json
      res = https.request(request)
      p res.code
      p res.body
      if res.body != nil
        out_resp = {:code => res.code, :message => res.message, :body => {:answ => JSON.parse(res.body.to_s)}}
      else
        out_resp = {:code => res.code, :message => res.message, :body => {:answ => "no data"}}
      end
    rescue
      out_resp = {:code => 500, :message => "dev_modify_location_v2: Unknown IOT error"}
    end
    p out_resp
    out_resp
  end



  ##2.10.7 Adding Members to a Device Group


  ##############################################################3


  ########final procedures###############

  def modify_location_iot(app_id, secret, dev_id, address)

    out_resp = {}
    begin
      token = self.get_token(app_id, secret)
      if token[:code] != 500 && token[:body]["accessToken"]!=nil
        out_resp = self.dev_modify_location_v2(app_id, dev_id, token[:body]["accessToken"], address)
        if out_resp[:code].to_i == 200 || out_resp[:code].to_i == 204
          ###logout#
          begin
            self.token_logout(token[:body]["accessToken"])
          rescue
            nil
          end
          ##########
        end
      else
        out_resp = {:code => 500, :message => "modify_location_iot: Invalid IOT platform token"}
      end
    rescue
      out_resp = {:code => 500, :message => "modify_location_iot: Unknown error"}
    end
    jjj = {:procedure => "modify_location_iot", :answ => out_resp}
    internal_func.printer_texter(jjj, "debug")
    out_resp
  end

  def add_new_device_on_huawei(app_id, secret, node_id, name_p, description_p, device_type, profile, manufacturer_id, manufacturer_name, model)
    self.dev_register_passw_code_mode2(app_id, secret, node_id, name_p, description_p, device_type, profile, manufacturer_id, manufacturer_name, model)
  end

  def add_new_device_on_huawei2(app_id, secret, attr_list)
    self.dev_reg_passw_code_mode2_2(app_id, secret, attr_list)
  end


  def remove_one_device_from_iot(app_id, secret, dev_id)
    out_resp = {}
    begin
      token = self.get_token(app_id, secret)
      if token[:code] != 500 && token[:body]["accessToken"]!=nil
        out_resp = self.dev_delete(app_id, dev_id, token[:body]["accessToken"])
        if out_resp[:code].to_i == 200 || out_resp[:code].to_i == 204
          ###logout#
          begin
            self.token_logout(token[:body]["accessToken"])
          rescue
            nil
          end
          ##########
        end
      else
        out_resp = {:code => 500, :message => "remove_one_device_from_iot: Invalid IOT platform token"}
      end
    rescue
      out_resp = {:code => 500, :message => "remove_one_device_from_iot: Unknown error"}
    end
    jjj = {:procedure => "remove_one_device_from_iot", :answ => out_resp}
    internal_func.printer_texter(jjj, "debug")
    out_resp
  end

  def quer_dev_query_list(app_id, secret, dev_list)
    out_resp = {}
    begin
      token = self.get_token(app_id, secret)
      if token[:code] != 500 && token[:body]["accessToken"]!=nil
        out_resp = self.quer_dev_direct_conn_batches(app_id, dev_list, token[:body]["accessToken"])
        if out_resp[:code].to_i == 200 || out_resp[:code].to_i == 204
          ###logout#
          begin
            self.token_logout(token[:body]["accessToken"])
          rescue
            nil
          end
          ##########
        end
      else
        out_resp = {:code => 500, :message => "quer_dev_query_list: Invalid IOT platform token"}
      end
    rescue
      out_resp = {:code => 500, :message => "quer_dev_query_list: Unknown error"}
    end
    jjj = {:procedure => "quer_dev_query_list", :answ => out_resp}
    internal_func.printer_texter(jjj, "debug")
    out_resp
  end


  #######################################

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