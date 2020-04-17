require 'mongo'

require 'json'
require 'rubygems'
require 'nokogiri'
require 'rails'
require "imperituroard/projects/iot/internal_functions"

#class for communication with mongo database for iot API
class MongoIot

  attr_accessor :mongo_ip, :mongo_port, :client, :mongo_database, :internal_func

  def initialize(mongo_ip, mongo_port, mongo_database)
    @mongo_database = mongo_database
    @mongo_ip = mongo_ip
    @mongo_port = mongo_port
    client_host = [mongo_ip + ":" + mongo_port]
    @client = Mongo::Client.new(client_host, :database => mongo_database)
    @internal_func = InternalFunc.new
  end

  def audit_logger(proc_name, src_ip, input_json, output_json, real_ip)
    out_resp = {}
    begin
      current = DateTime.now
      collection = client[:audit]
      doc = {
          :proc_name => proc_name,
          :date => current,
          :sender => {:src_ip => src_ip, :real_ip => real_ip},
          :input_params => input_json,
          :output_params => output_json
      }
      result = collection.insert_one(doc)
      out_resp = {:code => 200, :result => "audit_logger: Request completed successfully", :body => result}
    rescue
      out_resp = {:code => 507, :result => "audit_logger: Unknown SDK error"}
    end
    internal_func.printer_texter(out_resp, "debug")
    out_resp
  end

  #:code => 507, :result => "Unknown SDK error"
  #{:code => 200, :result => "Request completed successfully", :body => result_ps}
  def get_profiles_by_login(login)
    out_resp = {}
    begin
      p "get_profiles_by_login get_profiles_by_login"
      login_profiles = []
      req2 = []
      result_ps = []
      collection = client[:users]
      collection2 = client[:device_profiles]
      collection.find({:login => login}).each {|row|
        login_profiles = row["permit_profiles"]
      }
      p login_profiles
      if login_profiles !=[]
        for i in login_profiles
          req2.append({:profile_id => i})
        end
        collection2.find({:$or => req2}, {:_id => 0}).each {|row|
          result_ps.append(row)
        }
        out_resp = {:code => 200, :result => "get_profiles_by_login: Request completed successfully", :body => result_ps}
      else
        out_resp = {:code => 404, :result => "get_profiles_by_login: Access denied. Incorrect login"}
      end

    rescue
      out_resp = {:code => 507, :result => "get_profiles_by_login: Unknown SDK error"}
    end
    internal_func.printer_texter(out_resp, "debug")
    out_resp
  end

  def get_imei_info_from_db(imeilist)
    out_resp = {}
    p imeilist
    p "imeilist"
    begin
      req2 = []
      result_ps = []
      collection = client[:device_imei]
      for i in imeilist
        req2.append({:imei => i})
      end
      collection.find({:$or => req2}, {:_id => 0}).each {|row|
        result_ps.append(row)
      }
      out_resp = {:code => 200, :result => "get_imei_info_from_db: Request completed successfully", :body => result_ps}
    rescue
      out_resp = {:code => 507, :result => "get_imei_info_from_db: Unknown SDK error"}
    end
    internal_func.printer_texter(out_resp, "debug")
    out_resp
  end

  def get_profile_id_by_name(profile_name)
    begin
      result_ps = []
      collection = client[:device_profiles]
      collection.find({"profile" => profile_name}).each {|row|
        result_ps.append(row)
      }
      result_ps[0]
    rescue
      []
    end
  end

  def get_profile_name_by_id(profile_id)
    begin
      result_ps = []
      collection = client[:device_profiles]
      collection.find({"profile_id" => profile_id}).each {|row|
        result_ps.append(row)
      }
      result_ps[0]
    rescue
      []
    end
  end

  def check_login_profile_permiss(login, profile)
    out_resp = {}
    p "profile"
    p profile
    get_login_info = get_profiles_by_login(login)
    p "get_login_info"
    p get_login_info

    if get_login_info[:code]==200


      dst_profile = get_profile_id_by_name(profile)
      p "dst_profile"
      p dst_profile
      access=1
      if get_login_info[:body]!=[]
        if dst_profile!=[]
          p "sgsgsd"
          for j in get_login_info[:body]
            p j
            if j["profile_id"].to_i==dst_profile["profile_id"].to_i
              access=0
            end
            if access==0
              out_resp = {:code => 200, :result => "check_login_profile_permiss: Permission granted"}
            else
              out_resp = {:code => 400, :result => "check_login_profile_permiss: Access denied. This incident will be reported."}
            end
          end
        else
          out_resp = {:code => 501, :result => "check_login_profile_permiss: Profile not found"}
        end
      else
        out_resp = {:code => 500, :result => "check_login_profile_permiss: Access denied. Login not found"}
      end
    else
      out_resp = {:code => 500, :result => "check_login_profile_permiss: Access denied. Login not found"}
    end
    internal_func.printer_texter(out_resp, "debug")
    out_resp
  end


  def check_login_prof_perm_id_one(login, profile_id)
    out_resp = {}
    p "profile"
    p profile_id
    get_login_info = get_profiles_by_login(login)
    p "get_login_info"
    p get_login_info
    access=1
    if get_login_info[:body]!=[]
      p "sgsgsd"
      for j in get_login_info[:body]
        p j
        if j["profile_id"].to_i==profile_id.to_i
          access=0
        end
        if access==0
          out_resp = {:code => 200, :result => "check_login_prof_perm_id_one: Permission granted"}
        else
          out_resp = {:code => 400, :result => "check_login_prof_perm_id_one: Access denied. This incident will be reported."}
        end
      end
    else
      out_resp = {:code => 500, :result => "check_login_prof_perm_id_one: Login not found"}
    end
    internal_func.printer_texter(out_resp, "debug")
    out_resp
  end

  def check_imei_exists(imei_list)
    out_resp = {}
    res_exists = []
    imei_list_res = get_imei_info_from_db(imei_list)
    p imei_list_res
    p "imei_list"
    for k in imei_list_res[:body]
      p k
      res_exists.append(k["imei"])
    end
    p "aaaa"
    p imei_list
    p res_exists
    not_ex = imei_list - res_exists
    p "not_ex"
    p not_ex
    p res_exists
    out_resp = {:code => 200, :result => "check_imei_exists: Request completed successfully",
                :body => {:exists => res_exists, :not_exists => not_ex}}
    internal_func.printer_texter(out_resp, "debug")
    out_resp
  end


  def imei_insert_list(imei_list)
    begin
      collection = client[:device_imei]
      p imei_list
      for l in imei_list
        doc = {
            imei: l,
            imsi: "unknown",
            msisdn: "unknown",
            description: "test imei",
            note: "second description",
            profile: 0,
            type: 0,
            address: "unknown"
        }
        result = collection.insert_one(l)
        p result
      end
    rescue
      nil
    end
  end


  def imei_insert_list2(imei_list)
    begin
      collection = client[:device_imei]
      p imei_list
      for l in imei_list
        doc = {
            imei: l,
            imsi: "unknown",
            msisdn: "unknown",
            description: "test imei",
            note: "second description",
            profile: 0,
            type: 0,
            address: "unknown"
        }
        result = collection.insert_one(l)
        p result
      end
    rescue
      nil
    end
  end


  def imei_insert_model(model)
    begin
      collection = client[:device_types]
      result = collection.insert_one(model)
      p result
    rescue
      nil
    end
  end


  def get_profile_name_from_imei(imei)
    out_resp = {}
    begin
      id = ""
      begin
        info = get_imei_info_from_db([imei])
        p info
        p "info"
        if info[:body]==[]
          out_resp = {:code => 505, :result => "get_profile_name_from_imei: get_imei_info_from_db returned empty list from database. IMEIS not found"}
        else
          p "fshhsdf"
          p info
          id = info[:body][0]["profile"]
          p id
          p "id"

          begin
            p id
            res = get_profile_name_by_id(id)
            p res
            if res.key?("profile")
              res=res
            else
              out_resp = {:code => 505, :result => "get_profile_name_from_imei: Function get_profile_name_by_id not returned profile. Invalid data in database and returned: #{res.to_s}"}
            end
          rescue
            out_resp = {:code => 506, :result => "get_profile_name_from_imei: Function get_profile_name_by_id not processed correctly and returned: #{res.to_s}"}

          end
          begin
            if res["profile"]!=nil
              out_resp = {:code => 200, :result => "get_profile_name_from_imei: Request completed successfully", :body => res}
            end
          rescue
            out_resp = {:code => 506, :result => "get_profile_name_from_imei: Function get_profile_name_by_id not processed correctly and returned: #{res.to_s}"}
          end
        end
      rescue
        out_resp = {:code => 506, :result => "get_profile_name_from_imei: Function get_imei_info_from_db not processed correctly and returned: #{info.to_s}"}
      end

    rescue
      out_resp = {:code => 507, :result => "get_profile_name_from_imei: Unknown SDK error"}
    end
    internal_func.printer_texter(out_resp, "debug")
    out_resp
  end


  def device_remove_single_mongo(imei)
    out_resp = {}
    begin
      collection = client[:device_imei]
      doc = {
          "imei" => imei
      }
      result = collection.delete_many(doc)
      p result
      out_resp = {:code => 200, :result => "device_remove_single_mongo: Request completed successfully"}
    rescue
      out_resp = {:code => 507, :result => "device_remove_single_mongo: Unknown SDK error"}
    end
    internal_func.printer_texter(out_resp, "debug")
    out_resp
  end

  def device_modify_attr_mongo(imei, address)
    out_resp = {}
    begin
      collection = client[:device_imei]
      doc = {
          "imei" => imei
      }
      sett = {'$set' => {address: address}}
      result = collection.update_one(doc, sett)
      out_resp = {:code => 200, :result => "device_modify_attr_mongo: Request completed successfully"}
    rescue
      out_resp = {:code => 507, :result => "device_modify_attr_mongo: Unknown SDK error"}
    end
    internal_func.printer_texter(out_resp, "debug")
    out_resp
  end

  def device_modify_any_attr_mongo(imei, attr_list)
    out_resp = {}
    begin
      collection = client[:device_imei]
      doc = {
          "imei" => imei
      }
      sett = {'$set' => attr_list}
      result = collection.update_one(doc, sett)
      p result
    rescue
      continue
    end
  end


  def get_iot_oceanconnect_credent(login)
    out_resp = {}
    begin
      result_ps = []
      collection = client[:users]
      collection.find({"login" => login}).each {|row|
        result_ps.append(row)
      }
      p result_ps[0]
      app_id = result_ps[0][:iot_data][:app_id]
      secret = result_ps[0][:iot_data][:secret]
      out_resp = {:code => 200, :result => "get_iot_oceanconnect_credent: Request completed successfully", :body => {:app_id => app_id, :secret => secret}}
    rescue
      out_resp = {:code => 500, :result => "get_iot_oceanconnect_credent: Process failed"}
    end
    internal_func.printer_texter(out_resp, "debug")
    out_resp
  end


  def get_device_type_info_by_model(device_model)
    out_resp = {}
    begin
      result_ps = []
      collection = client[:device_types]
      collection.find({"model" => device_model}).each {|row|
        result_ps.append(row)
      }
      dattaa = result_ps[0]
      if dattaa!=nil
        out_resp = {:code => 200, :result => "get_device_type_info_by_model: Request completed successfully", :body => dattaa}
      else
        out_resp = {:code => 404, :result => "get_device_type_info_by_model: Device info not found", :body => {"model" => device_model, "ManufacturerID" => "unknown", "ManufacturerNAME" => "unknown", "device_type" => "unknown"}}
      end
    rescue
      out_resp = {:code => 500, :result => "get_device_type_info_by_model: procedure error", :body => {"model" => device_model, "ManufacturerID" => "unknown", "ManufacturerNAME" => "unknown", "device_type" => "unknown"}}
    end
    internal_func.printer_texter(out_resp, "debug")
    out_resp
  end


  def ttt
    p "111111"
    begin
      puts(client.cluster.inspect)
      puts('Collection Names: ')
      puts(client.database.collection_names)
      puts('Connected!')
      collection = client[:audit]
      doc = {
          name: 'Steve',
          hobbies: ['hiking', 'tennis', 'fly fishing'],
          siblings: {
              brothers: 0,
              sisters: 1
          }
      }
      result = collection.insert_one(doc)
      p result
      client.close
    rescue StandardError => err
      puts('Error: ')
      puts(err)
    end


  end
end