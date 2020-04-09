$LOAD_PATH.unshift File.expand_path("../projects/iot", __dir__)
$LOAD_PATH.unshift File.expand_path("../projects/wttx", __dir__)

require "imperituroard/version"
require "imperituroard/phpipamdb"
require "imperituroard/phpipamcps"
require "imperituroard/projects/iot/mongoconnector"
require "imperituroard/projects/iot/hua_oceanconnect_adapter"
require "imperituroard/projects/iot/add_functions"
require 'json'
require 'ipaddr'

module Imperituroard
  class Error < StandardError;
  end

  def initialize()
  end

  def hhh(jjj)
    p jjj
  end
  # Your code goes here...
end

module PhpipamModule
  def test(ggg)
    p ggg
  end
end

class MyJSON
  def self.valid?(value)
    result = JSON.parse(value)

    result.is_a?(Hash) || result.is_a?(Array)
  rescue JSON::ParserError, TypeError
    false
  end
end

class Pipam

  attr_accessor :username, :password, :ip, :database_class, :cps_class

  def initialize(db_username, db_password, db_ip, cps_wsdl, cps_endpoint, cps_namespace)
    @username = db_username
    @password = db_password
    @ip = db_ip
    @database_class = Pdb.new("phpipam", db_username, db_password, db_ip, "3306")
    @cps_class = Pcps.new(cps_wsdl, cps_endpoint, cps_namespace)
  end

  def update_phpipam_rewr_msisdn(old_msisdn, new_msisdn)

    dst_num_exists = database_class.check_if_msisdn_exists(new_msisdn, "ipaddresses")
    if dst_num_exists == 0
      database_class.update_database_rewrite_msisdn(old_msisdn, new_msisdn)
      "updated"
    else
      "failed"
    end
  end

  def final_change_msisdn(old_msisdn, new_msisdn)
    dst_num_exists = database_class.check_if_msisdn_exists(new_msisdn, "ipaddresses")
    if dst_num_exists == 0
      response_from_db = database_class.update_database_rewrite_msisdn(old_msisdn, new_msisdn)
      if response_from_db=="success"
        response_from_cps = cps_class.change_attr_cps(old_msisdn, new_msisdn)
        if response_from_cps == "ok"
          "updated"
        else
          "cps failed"
        end
      else
        "db failed"
      end
    else
      "failed"
    end
  end

  include PhpipamModule
end

class Iot
  attr_accessor :mongoip,
                :mongoport,
                :iotip,
                :iottoken,
                :mongo_database,
                :iotplatform_ip,
                :iotplatform_port,
                :cert_path,
                :key_path,
                :mongo_client,
                :add_functions_connector

  def initialize(mongoip, mongoport, iotip, mongo_database,
                 iotplatform_ip, iotplatform_port, cert_path, key_path, telegram_api_url, telegram_chat_id)
    @mongoip = mongoip
    @mongoport = mongoport
    @iotip = iotip
    @mongo_database = mongo_database
    @iotplatform_ip = iotplatform_ip
    @iotplatform_port = iotplatform_port
    @cert_path = cert_path
    @key_path = key_path
    @mongo_client = MongoIot.new(mongoip, mongoport, mongo_database)
    @add_functions_connector = AdditionalFunc.new(telegram_api_url, telegram_chat_id)
  end

  #error list

  #:code => 507, :result => "Unknown SDK error"
  #{:code => 200, :result => "Request completed successfully", :body => result_ps}


  #!1. Add device to profile (only for new device)
  #login - login for client identification
  #profile - profile for device
  #imei_list - device identificator
  #imei_list = [{"imei" => 131234123412341233, "description" => "dfdsf", "note"=>"second description", "profile"=>0},
  #{"imei" => 56213126347645784, "description" => "dfdsf", "note"=>"second description", "profile"=>0}]
  #massive commands
  #++
  def add_device_to_profile(login, imei_list, remote_ip)
    input_json = {:login => login, :imei_list => imei_list}
    resp_out = {}
    begin
      thr1 = Thread.new do

        imei = []
        list1 = {}
        for_insert = []
        not_processed_list = []
        processed_list = []

        for ii in imei_list
          list1[ii["imei"]] = ii
          imei.append(ii["imei"])
        end
        list_checked = mongo_client.check_imei_exists(imei)
        for ss in list_checked[:body][:exists]
          not_processed_list.append({:imei => ss, :error => "Device exists in database"})
        end

        for jj in list_checked[:body][:not_exists]
          begin
            get_login_info = mongo_client.check_login_prof_perm_id_one(login, list1[jj]["profile"])[:code]
            if get_login_info==200


              for_insert.append(list1[jj])
            else
              not_processed_list.append({:imei => list1[jj], :error => "Permission denied for this profile"})
            end
          rescue
            not_processed_list.append({:imei => list1[jj], :error => "Unknown error"})
          end
        end

        begin
          if for_insert!=[]
            ##Logic for IOT Platform connection###

            #########end iot platform logic#######

            mongo_client.imei_insert_list(for_insert)
            resp_out = {:code => 200, :result => "Data processed", :body => {:imei_processed => for_insert, :error_list => not_processed_list}}
          else
            resp_out = {:code => 202, :result => "Nothing for insertion", :body => {:imei_processed => for_insert, :error_list => not_processed_list}}

          end
        rescue
          resp_out = {:code => 505, :result => "Error with database communication"}
        end
      end
    rescue
      resp_out = {:code => 507, :result => "Unknown SDK error"}
    end
    thr1.join
    mongo_client.audit_logger("add_device_to_profile", remote_ip, input_json, resp_out)
    resp_out
  end


  #!2 Find device (only mongo datebase. IOT platform not need)
  # procedure for data selection from mongo database.
  # for this function IOT platform not need
  # login
  # imei
  # imei_list =[41234,23452345,132412]
  #++
  def device_find(login, imei_list, remote_ip)
    input_json = {:login => login, :imei_list => imei_list}
    ime_list_approved = []
    ime_list_notapproved = []
    resp = {}
    begin
      thr2 = Thread.new do
        for t in imei_list
          prof_name1 = mongo_client.get_profile_name_from_imei(t)
          if prof_name1[:code]==200
            begin
              permiss1 = mongo_client.check_login_profile_permiss(login, prof_name1[:body]["profile"])[:code]
              if permiss1==200
                ime_list_approved.append(t)
              else
                ime_list_notapproved.append({:imei => t, :error => permiss1})
              end
            rescue
              ime_list_notapproved.append({:imei => t, :error => {:code => 405, :result => "Unknown error when check_login_profile_permiss imei #{t.to_s}"}})
            end
          else
            ime_list_notapproved.append({:imei => t, :error => prof_name1})
          end
        end
        begin
          if ime_list_approved != []
            data = mongo_client.get_imei_info_from_db(ime_list_approved)

            resp = {:code => 200, :result => "Request completed successfully", :data => {:approved_list => data, :unapproved_list => ime_list_notapproved}}

          else
            resp = {:code => 404, :result => "Invalidate data", :data => {:approved_list => [], :unapproved_list => ime_list_notapproved}}
          end
        rescue
          resp = {:code => 504, :result => "Unsuccessfully data transfer"}
        end
      end
    rescue
      resp = {:code => 507, :result => "Unknown SDK error"}
    end
    thr2.join
    mongo_client.audit_logger("device_find", remote_ip, input_json, resp)
    resp
  end

  #!3 device modify, change imei
  #login
  #imei_old
  #imei_new
  #massive commands
  #im_list = [{"imei_old"=>7967843245667, "imei_new"=>7967843245665}]
  #++
  def imei_replace(login, im_list, remote_ip)
    input_json = {:login => login, :imei_list => im_list}

    li_new_imei = []
    list1 = {}
    not_processed_list = []
    approved_list = []
    resp_out = {}

    for pr1 in im_list
      p "pr1"
      p pr1
      li_new_imei.append(pr1["imei_new"])
      list1[pr1["imei_new"]]=pr1["imei_old"]
    end

    p list1

    begin

      thr3 = Thread.new do

        list_checked = mongo_client.check_imei_exists(li_new_imei)
        for ss in list_checked[:body][:exists]
          not_processed_list.append({:record => {:imei_old => list1[ss], :imei_new => ss}, :error => "New IMEI exists in database"})
        end

        step2_list = list_checked[:body][:not_exists]

        for a in step2_list
          begin
            p "list1[a]"
            p list1
            p a
            p list1[a]
            prof_name1 = mongo_client.get_profile_name_from_imei(list1[a])

            p prof_name1
            if prof_name1[:code]==200

              p "if prof_name1[:code]==200"

              permiss1 = mongo_client.check_login_profile_permiss(login, prof_name1[:body]["profile"])[:code]
              p "permiss1"
              p permiss1
              if permiss1==200

                ##Logic for IOT Platform connection###

                #########end iot platform logic#######

                mongo_client.device_modify_any_attr_mongo(list1[a], {:imei => a})

                approved_list.append({:imei_old => list1[a], :imei_new => a})


              else
                not_processed_list.append({:record => {:imei_old => list1[a], :imei_new => a}, :error => "Old IMEI modification denied"})
              end
            else
              not_processed_list.append({:record => {:imei_old => list1[a], :imei_new => a}, :error => "Old IMEI not exists in database"})
            end
          rescue
            not_processed_list.append({:record => {:imei_old => list1[a], :imei_new => a}, :error => "Unknown error"})
          end
        end

        if approved_list!=[]
          resp_out = {:code => 200, :result => "Request completed successfully", :data => {:approved_list => approved_list, :unapproved_list => not_processed_list}}
        else
          resp_out = {:code => 202, :result => "Nothing to do", :data => {:approved_list => approved_list, :unapproved_list => not_processed_list}}
        end

      end


    rescue
      resp_out = {:code => 507, :result => "Unknown SDK error"}
    end

    thr3.join
    mongo_client.audit_logger("imei_replace", remote_ip, input_json, resp_out)

    resp_out

  end


  #!4 remove device
  #login
  #imei
  # not massive commands
  #imei=11341341234
  #login="test"
  #++
  def device_remove(login, imei, remote_ip)

    input_json = {:login => login, :imei_list => imei}
    resp_out = {}

    begin
      thr4 = Thread.new do
      prof_name = mongo_client.get_profile_name_from_imei(imei)
      if prof_name[:code]==200
        permiss = mongo_client.check_login_profile_permiss(login, prof_name[:body]["profile"])
        if permiss[:code]==200

          ##Logic for IOT Platform connection###

          #########end iot platform logic#######

          resp = mongo_client.device_remove_single_mongo(imei)

          if resp[:code]==200
            resp_out = {:code => 200, :result => "Request completed successfully"}
          else
            resp_out=resp
          end
        else
          resp_out=permiss
        end
      else
        resp_out=prof_name
      end
      end

    rescue
      resp_out = {:code => 507, :result => "Unknown SDK error"}
    end
    thr4.join
    mongo_client.audit_logger("device_remove", remote_ip, input_json, resp_out)
    resp_out
  end


  #!5 add address to device
  #login
  #imei = newdevice_list
  #address = newdevice_list
  #newdevice_list=[{:imei=>7967843245665, :address=>"Golubeva51"}]
  #++
  def device_add_address(login, newdevice_list, remote_ip)
    #add_functions_connector.telegram_message(newdevice_list.to_s)
    p newdevice_list
    p "gas"
    p MyJSON.valid?(newdevice_list[0].to_s)
    p "sdfsdfgs"
    input_json = {:login => login, :devices => newdevice_list}
    resp_out = {}
    not_processed = []
    processed = []
    begin
      thr5 = Thread.new do
      for p in newdevice_list
        prof_name = mongo_client.get_profile_name_from_imei(p[:imei])

        if prof_name[:code]==200
          p "prof_name"
          p prof_name
          permiss = mongo_client.check_login_profile_permiss(login, prof_name[:body]["profile"])
          if permiss[:code]==200

            ##Logic for IOT Platform connection###

            #########end iot platform logic#######


            resp = mongo_client.device_modify_attr_mongo(p[:imei], p[:address])
            if resp[:code]==200
              processed.append({:imei=>p[:imei]})
            end
          else
            not_processed.append({:imei=>p[:imei], :address=>p[:address], :error=>permiss})
          end
        else
          not_processed.append({:imei=>p[:imei], :address=>p[:address], :error=>prof_name})
        end
      end

      if processed!=[]
        resp_out = {:code => 200, :result => "Request completed successfully", :body => {:imei_processed => processed, :error_list => not_processed}}
      else
        resp_out = {:code => 202, :result => "Nothing processed", :body => {:imei_processed => processed, :error_list => not_processed}}
      end
      end
    rescue
      resp_out = {:code => 507, :result => "Unknown SDK error"}
    end
    thr5.join
    mongo_client.audit_logger("device_add_address", remote_ip, input_json, resp_out)
    resp_out
  end


  #6 add service by SPA
  #imei
  #profile
  #imsi
  #msisdn
  #newdevice_list=[{:imei=>7967843245665, :attributes=>{:address=>"Golubeva51", :profile=>"wqeqcqeqwev", :msisdn=>375298766719, :imsi=>25702858586756875}}]
  #+
  def add_service(login, device_list, remote_ip)

    resp_out = {}

    not_processed = []
    processed = []


    input_json = {:login => login, :devices => device_list}

    begin

      for g in device_list
        p g

        prof_name1 = mongo_client.get_profile_name_from_imei(g["imei"])
        p prof_name1

        if prof_name1[:code]==200
          p prof_name1
          permiss1 = mongo_client.check_login_profile_permiss(login, prof_name1[:body]["profile"])
          p "permiss1"
          p permiss1
          if permiss1[:code]==200

            if g["attributes"].key?("profile")
              permiss2 = mongo_client.check_login_profile_permiss(login, g["attributes"]["profile"])[:code]

              if permiss2==200

                attr = g["attributes"]
                #mod_attr = {}

                if attr.key?("profile")
                  if attr["profile"].is_a? Integer
                    p "Ok"
                  else
                    p new = mongo_client.get_profile_id_by_name(attr["profile"])
                    attr["profile"] = new["profile_id"]
                  end
                end
                p attr

                mongo_client.device_modify_any_attr_mongo(g["imei"], attr)

                processed.append(g["imei"])

              else
                not_processed.append({:imei=>g["imei"], :description=> "New profile permission error", :error=>permiss2 })
              end

            else
              attr = g["attributes"]
              mongo_client.device_modify_any_attr_mongo(g["imei"], attr)

              processed.append(g["imei"])

            end


          else
            not_processed.append({:imei=>g["imei"], :description=> "Old profile permission error", :error=>permiss1 })
          end

        else
          not_processed.append({:imei=>g["imei"],:error=>prof_name1})
        end

      end
      resp_out = {:code => 200, :result => "Request completed successfully", :body => {:imei_processed => processed, :error_list => not_processed}}

    rescue
      resp_out = {:code => 507, :result => "Unknown SDK error"}
    end
    mongo_client.audit_logger("device_remove", remote_ip, input_json, resp_out)
    resp_out
  end


  def test()
    ddd = MongoIot.new(mongoip, mongoport, mongo_database)
    #ddd.get_profiles_by_login("test")

    ff = [131234123412341233, 131234123127341233]
    #ddd.get_imsi_info_from_db(ff)

    p ddd.get_profile_id_by_name("1341241")
  end


  def testhua()
    cert_file = cert_path
    key_file = key_path
    ddd1 = HuaIot.new(iotplatform_ip, iotplatform_port, "", "", cert_file, key_file)
    #p ddd1.dev_register_verif_code_mode("Cd1v0k2gTBCbpQlMVlW1FVqOSqga", "kbfo5JlBxTIhjVwtjHleWS5Iw5wa", "7521234165452")
    #ddd1.querying_device_id("Cd1v0k2gTBCbpQlMVlW1FVqOSqga", "kbfo5JlBxTIhjVwtjHleWS5Iw5wa", "a8834c5e-4b4d-4f0f-ad87-14e916f3d0bb")
    #ddd1.querying_device_activ_status("Cd1v0k2gTBCbpQlMVlW1FVqOSqga", "kbfo5JlBxTIhjVwtjHleWS5Iw5wa", "7521234165452")
    #ddd1.querying_device_info("Cd1v0k2gTBCbpQlMVlW1FVqOSqga", "kbfo5JlBxTIhjVwtjHleWS5Iw5wa", "a8834c5e-4b4d-4f0f-ad87-14e916f3d0bb")
    list = ["41c0ba82-d771-4669-b766-fcbfbedc17f4", "7521234165452", "feb9c4d1-4944-4b04-a717-df87dfde30f7", "9868e121-c309-4f4f-8ab3-0aa69072caff", "b3b82f35-0723-4a83-90af-d4ea40017194"]
    #p ddd1.querying_device_direct_conn("Cd1v0k2gTBCbpQlMVlW1FVqOSqga", "kbfo5JlBxTIhjVwtjHleWS5Iw5wa", list)
    #p ddd1.querying_device_type_list("Cd1v0k2gTBCbpQlMVlW1FVqOSqga", "kbfo5JlBxTIhjVwtjHleWS5Iw5wa")
    p ddd1.querying_device_id("Cd1v0k2gTBCbpQlMVlW1FVqOSqga", "kbfo5JlBxTIhjVwtjHleWS5Iw5wa", "7521234165452")
    #ddd1.dev_delete("Cd1v0k2gTBCbpQlMVlW1FVqOSqga", "kbfo5JlBxTIhjVwtjHleWS5Iw5wa", "484114f6-a49c-4bab-88e6-4ddaf1cc1c8f")
  end


  def testhua2()
    tt = "{\"deviceId\":\"fad0a417-b6a3-4b0b-abfc-fa2b0af9691a\",\"verifyCode\":\"6cb6dcca\",\"timeout\":180,\"psk\":\"1d16b55d577bc1f2e5e75d416ce6b8a2\"}"
    #tt = tt.gsub("\\","")
    #p tt
    ff = tt.to_s
    p ff
    gg = JSON.parse(ff)
    p gg
  end

end

