require 'mongo'

require 'json'
require 'rubygems'
require 'nokogiri'
require 'rails'

#class for communication with mongo database for iot API
class MongoIot

  attr_accessor :mongo_ip, :mongo_port, :client, :mongo_database

  def initialize(mongo_ip, mongo_port, mongo_database)
    @mongo_database = mongo_database
    @mongo_ip = mongo_ip
    @mongo_port = mongo_port
    client_host = [mongo_ip + ":" + mongo_port]
    @client = Mongo::Client.new(client_host, :database => mongo_database)
  end

  def audit_logger(proc_name, src_ip, input_json, output_json)
    begin
      d = DateTime.now
      current = d.strftime("%d/%m/%Y %H:%M:%S")
      collection = client[:audit]
      doc = {
          :proc_name => proc_name,
          :date => current,
          :sender => {:src_ip => src_ip},
          :input_params => input_json,
          :output_params => output_json
      }
      result = collection.insert_one(doc)
      return {:code => 200, :result => "Request completed successfully", :body => result}
    rescue
      return {:code => 507, :result => "Unknown SDK error"}
    end
  end

  #:code => 507, :result => "Unknown SDK error"
  #{:code => 200, :result => "Request completed successfully", :body => result_ps}
  def get_profiles_by_login(login)
    begin
      login_profiles = []
      req2 = []
      result_ps = []
      collection = client[:users]
      collection2 = client[:device_profiles]
      collection.find({:login => login}).each {|row|
        login_profiles = row["permit_profiles"]
      }
      for i in login_profiles
        req2.append({:profile_id => i})
      end
      collection2.find({:$or => req2}, {:_id => 0}).each {|row|
        result_ps.append(row)
      }
      return {:code => 200, :result => "Request completed successfully", :body => result_ps}
    rescue
      return {:code => 507, :result => "Unknown SDK error"}
    end
  end

  def get_imei_info_from_db(imeilist)
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
      return {:code => 200, :result => "Request completed successfully", :body => result_ps}
    rescue
      return {:code => 507, :result => "Unknown SDK error"}
    end
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
    p "profile"
    p profile
    get_login_info = get_profiles_by_login(login)
    p "get_login_info"
    p get_login_info
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
            return {:code => 200, :result => "Permission granted"}
          else
            return {:code => 400, :result => "Access denied. This incident will be reported."}
          end
        end
      else
        return {:code => 501, :result => "Profile not found"}
      end
    else
      {:code => 500, :result => "Login not found"}
    end
  end


  def check_login_prof_perm_id_one(login, profile_id)
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
          return {:code => 200, :result => "Permission granted"}
        else
          return {:code => 400, :result => "Access denied. This incident will be reported."}
        end
      end
    else
      {:code => 500, :result => "Login not found"}
    end
  end

  def check_imei_exists(imei_list)
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
    {:code => 200, :result => "check_imei_exists: Request completed successfully",
     :body => {:exists => res_exists, :not_exists => not_ex}}
  end


  def imei_insert_list(imei_list)
    begin
      collection = client[:device_imei]
      p imei_list
      for l in imei_list
        doc = {
            imei: l,
            imsi: "",
            msisdn: "",
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
      continue
    end
  end

  def get_profile_name_from_imei(imei)
    begin
      begin
        info = get_imei_info_from_db([imei])
        if info[:body]==[]
          return {:code => 505, :result => "get_profile_name_from_imei: get_imei_info_from_db returned empty list from database. IMEIS not found"}
        else
          p "fshhsdf"
          p info
          id = info[:body][0]["profile"]
        end
      rescue
        return {:code => 506, :result => "get_profile_name_from_imei: Function get_imei_info_from_db not processed correctly and returned: #{info.to_s}"}
      end
      begin
        res = get_profile_name_by_id(id)
        if res.key?("profile")
          res=res
        else
          return {:code => 505, :result => "get_profile_name_from_imei: Function get_profile_name_by_id not returned profile. Invalid data in database and returned: #{res.to_s}"}
        end

      rescue
        return {:code => 506, :result => "get_profile_name_from_imei: Function get_profile_name_by_id not processed correctly and returned: #{res.to_s}"}

      end
      begin
        if res["profile"]!=nil
          return {:code => 200, :result => "get_profile_name_from_imei: Request completed successfully", :body => res}
        end
      rescue
        return {:code => 506, :result => "get_profile_name_from_imei: Function get_profile_name_by_id not processed correctly and returned: #{res.to_s}"}
      end
    rescue
      return {:code => 507, :result => "get_profile_name_from_imei: Unknown SDK error"}
    end

  end


  def device_remove_single_mongo(imei)

    begin
      collection = client[:device_imei]
      doc = {
          "imei" => imei
      }
      result = collection.delete_many(doc)
      p result
      return {:code => 200, :result => "device_remove_single_mongo: Request completed successfully"}
    rescue
      return {:code => 507, :result => "device_remove_single_mongo: Unknown SDK error"}
    end

  end

  def device_modify_attr_mongo(imei, address)
    begin
      collection = client[:device_imei]
      doc = {
          "imei" => imei
      }
      sett = {'$set' => {address: address}}
      result = collection.update_one(doc, sett)
      return {:code => 200, :result => "device_modify_attr_mongo: Request completed successfully"}
    rescue
      return {:code => 507, :result => "device_remove_single_mongo: Unknown SDK error"}
    end
  end

  def device_modify_any_attr_mongo(imei, attr_list)
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