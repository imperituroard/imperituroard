$LOAD_PATH.unshift File.expand_path("../projects/iot", __dir__)
$LOAD_PATH.unshift File.expand_path("../projects/wttx", __dir__)

require "imperituroard/version"
require "imperituroard/phpipamdb"
require "imperituroard/phpipamcps"
require "imperituroard/projects/iot/mongoconnector"
require "imperituroard/projects/iot/hua_oceanconnect_adapter"
require "imperituroard/projects/iot/add_functions"
require "imperituroard/projects/iot/internal_functions"
require 'json'
require 'ipaddr'
require 'date'

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
                :mongo_database,
                :iotplatform_ip,
                :iotplatform_port,
                :cert_path,
                :key_path,
                :mongo_client,
                :add_functions_connector,
                :real_ip, #real ip address of procedure caller
                :remote_ip, #ip address of balancer
                :hua_aceanconnect_connector,
                :internal_func

  def initialize(mongoip, mongoport, iotip, mongo_database,
                 iotplatform_ip, iotplatform_port, cert_path, key_path, telegram_api_url, telegram_chat_id, real_ip, remote_ip)
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
    @real_ip = real_ip
    @remote_ip = remote_ip
    @hua_aceanconnect_connector = HuaIot.new(iotplatform_ip, iotplatform_port, cert_path, key_path)
    @internal_func = InternalFunc.new
  end

  #error list

  #:code => 507, :result => "Unknown SDK error"
  #{:code => 200, :result => "Request completed successfully", :body => result_ps}


  #!!1. Add device to profile (only for new device)
  #login - login for client identification
  #profile - profile for device
  #imei_list - device identificator
  #imei_list = [{"imei" => 131234123412341233, "description" => "dfdsf", "note"=>"second description", "profile"=>0, "device_type"=>"phone"},
  #{"imei" => 56213126347645784, "description" => "dfdsf", "note"=>"second description", "profile"=>0}]
  #massive commands
  #+++
  #iot logic added
  def add_device_to_profile(login, imei_list)
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
          added_on_iot_platf = []
          if for_insert!=[]
            ##Logic for IOT Platform connection###

            credentials = mongo_client.get_iot_oceanconnect_credent(login)

            if credentials[:code]==200
              for aaa in for_insert
                begin
                  dev_name = aaa["imei"].to_s

                  #get {"model"=>"BGT_PPMC", "ManufacturerID"=>"unknown", "ManufacturerNAME"=>"unknown", "device_type"=>"unknown"}
                  #from database
                  model_data = mongo_client.get_device_type_info_by_model(aaa["device_type"])
                  resss = hua_aceanconnect_connector.add_new_device_on_huawei(credentials[:body][:app_id],
                                                                              credentials[:body][:secret],
                                                                              aaa["imei"],
                                                                              dev_name,
                                                                              aaa["description"],
                                                                              model_data[:body]["device_type"],
                                                                              aaa["profile"],
                                                                              model_data[:body]["ManufacturerID"],
                                                                              model_data[:body]["ManufacturerNAME"],
                                                                              model_data[:body]["model"]
                  )
                  if resss[:code]=="200"
                    s1 = aaa
                    s1[:huadata] = resss
                    s1[:created] = DateTime.now
                    added_on_iot_platf.append(s1)
                  else
                    not_processed_list.append({:imei => aaa["imei"], :error => resss})
                  end
                rescue
                  not_processed_list.append({:imei => aaa["imei"], :error => "Unknown error with insertion imei on IOT platform"})
                end
              end

              #########end iot platform logic#######

              mongo_client.imei_insert_list(added_on_iot_platf)
              resp_out = {:code => 200, :result => "Data processed", :body => {:imei_processed => added_on_iot_platf, :error_list => not_processed_list}}
            else
              resp_out = {:code => 400, :result => "IOT platform credentials not found"}
            end


          else
            resp_out = {:code => 202, :result => "Nothing for insertion", :body => {:imei_processed => added_on_iot_platf, :error_list => not_processed_list}}

          end
        rescue
          resp_out = {:code => 505, :result => "Error with database communication"}
        end
      end
    rescue
      resp_out = {:code => 507, :result => "Unknown SDK error"}
    end
    thr1.join
    mongo_client.audit_logger("add_device_to_profile", remote_ip, input_json, resp_out, real_ip)
    resp_out
  end


  #!!2 Find device (only mongo datebase. IOT platform not need)
  # procedure for data selection from mongo database.
  # for this function IOT platform not need
  # login
  # imei
  # imei_list =[41234,23452345,132412]
  #++
  def device_find(login, imei_list)
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
              permiss1 = mongo_client.check_login_profile_permiss(login, prof_name1[:body]["profile"])
              p "permiss1"
              p permiss1
              if permiss1[:code]==200
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
    mongo_client.audit_logger("device_find", remote_ip, input_json, resp, real_ip)
    resp
  end

  #!3 device modify, change imei
  #login
  #imei_old
  #imei_new
  #massive commands
  #im_list = [{"imei_old"=>7967843245667, "imei_new"=>7967843245665}]
  #++
  def imei_replace(login, im_list)
    input_json = {:login => login, :imei_list => im_list}

    li_new_imei = []
    list1 = {}

    #dictionary for imeis which not processed. Final dictionary
    not_processed_list = []

    #dictionary for devices which was processed correctly
    processed_list = []

    #array for translations from old imei to new
    old_new_translation = {}

    approved_list = []
    resp_out = {}

    #old_imei_list for query to iot platform for data request
    step1_approved_dict_old=[]

    #form dictionary for processing
    for pr1 in im_list
      p "pr1"
      p pr1
      li_new_imei.append(pr1["imei_new"])
      list1[pr1["imei_new"]]=pr1["imei_old"]
      old_new_translation[pr1["imei_old"]]=pr1["imei_new"]
    end

    p list1

    begin

      thr3 = Thread.new do

        #check if imei_new exists in database. If exists - not process this imei
        list_checked = mongo_client.check_imei_exists(li_new_imei)

        internal_func.printer_texter({:function => "imei_replace Step1", :list_checked => list_checked}, "debug")

        #add already exists new IMEI in error dictionary
        for ss in list_checked[:body][:exists]
          not_processed_list.append({:record => {:imei_old => list1[ss], :imei_new => ss}, :error => "New IMEI exists in database"})
        end

        #new_imei list which processed step1
        step2_list = list_checked[:body][:not_exists]

        internal_func.printer_texter({:function => "imei_replace Step2", :step2_list => step2_list}, "debug")


        for a in step2_list
          begin

            #step3 checking permission for writing for imei list
            prof_name1 = mongo_client.get_profile_name_from_imei(list1[a])

            internal_func.printer_texter({:function => "imei_replace Step3", :prof_name1 => prof_name1}, "debug")

            if prof_name1[:code]==200
              permiss1 = mongo_client.check_login_profile_permiss(login, prof_name1[:body]["profile"])[:code]
              internal_func.printer_texter({:function => "imei_replace Step4", :permiss1 => permiss1, :input => prof_name1[:body]["profile"]}, "debug")
              if permiss1==200

                approved_list.append({:imei_old => list1[a], :imei_new => a})
                step1_approved_dict_old.append(list1[a])

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

        internal_func.printer_texter({:function => "imei_replace Step5", :not_processed_list => not_processed_list, :input => list1, :approved_list => approved_list, :step1_approved_dict_old => step1_approved_dict_old}, "debug")


        ##Logic for IOT Platform connection###

        list_from_iot = self.get_info_by_imeilist_from_iot(login, step1_approved_dict_old)

        internal_func.printer_texter({:function => "imei_replace Step6", :list_from_iot => list_from_iot, :description => "data from iot platform by old imei"}, "debug")

        #processing data. modifying data on iot platform and mongoDB
        if list_from_iot[:code]=="200"

          for ard in list_from_iot[:body]["devices"]
            p ard
            new_data_cur_dev = {}
            mongo_answer = {}
            current_old_dev = ard["deviceInfo"]["nodeId"]
            current_device_id = ard["deviceId"]
            new_data_cur_dev = ard["deviceInfo"]
            new_data_cur_dev["nodeId"] = old_new_translation[current_old_dev.to_i].to_s

            credentials = mongo_client.get_iot_oceanconnect_credent(login)

            if credentials[:code]==200
              flag_remove=0
              flag_create=0
              remove_answer = hua_aceanconnect_connector.remove_one_device_from_iot(credentials[:body][:app_id], credentials[:body][:secret], current_device_id)
              create_answer = hua_aceanconnect_connector.add_new_device_on_huawei2(credentials[:body][:app_id], credentials[:body][:secret], new_data_cur_dev)

              if remove_answer[:code]=="204" || remove_answer[:code]=="200"
                flag_remove=1
              end
              if create_answer[:code]=="200"
                flag_create=1
              end
              if flag_remove==1 && flag_create==1
                mongo_answer = mongo_client.device_modify_any_attr_mongo(current_old_dev.to_i, {:imei => old_new_translation[current_old_dev.to_i], :huadata => {:body => create_answer[:body]}, :updated => DateTime.now})
                processed_list.append({:imei_old => current_old_dev.to_i, :imei_new => old_new_translation[current_old_dev.to_i]})
              else
                not_processed_list.append({:record => {:imei_old => current_old_dev.to_i, :imei_new => old_new_translation[current_old_dev.to_i]}, :error => "Failed for provisioning to IOT platform"})
              end

              internal_func.printer_texter({:function => "imei_replace Step7", :remove_answer => remove_answer, :create_answer => create_answer, :mongo_answer => mongo_answer, :description => "processing imei #{current_old_dev.to_s}"}, "debug")

            else
              approved_list=[]
            end
          end

        else
          approved_list=[]
        end

        if approved_list!=[]
          resp_out = {:code => 200, :result => "Request completed successfully", :data => {:approved_list => processed_list, :unapproved_list => not_processed_list}}
        else
          resp_out = {:code => 202, :result => "Nothing to do", :data => {:approved_list => processed_list, :unapproved_list => not_processed_list}}
        end

      end

    rescue
      resp_out = {:code => 507, :result => "Unknown SDK error"}
    end

    thr3.join
    mongo_client.audit_logger("imei_replace", remote_ip, input_json, resp_out, real_ip)

    resp_out

  end


  #!!4 remove device
  #login
  #imei
  # not massive commands
  #imei=11341341234
  #login="test"
  #+++
  #IOT logic added
  def device_remove(login, imei)

    input_json = {:login => login, :imei_list => imei}
    resp_out = {}

    begin
      thr4 = Thread.new do
        prof_name = mongo_client.get_profile_name_from_imei(imei)
        if prof_name[:code]==200
          permiss = mongo_client.check_login_profile_permiss(login, prof_name[:body]["profile"])
          if permiss[:code]==200

            ##Logic for IOT Platform connection###


            credentials = mongo_client.get_iot_oceanconnect_credent(login)
            resp = {}

            if credentials[:code]==200

              imei_data = mongo_client.get_imei_info_from_db([imei])
              if imei_data[:body]!=[]
                ans = hua_aceanconnect_connector.remove_one_device_from_iot(credentials[:body][:app_id], credentials[:body][:secret], imei_data[:body][0]["huadata"]["body"]["deviceId"])
                p ans
                if ans[:code]=="204" or ans[:code]=="200"
                  resp = mongo_client.device_remove_single_mongo(imei)
                else
                  resp = {:code => 500, :result => "Unknown IOT platform error", :body => ans}
                end
              else
                resp_out = {:code => 404, :result => "Data not found"}
              end

              #########end iot platform logic#######

              if resp[:code]==200
                resp_out = {:code => 200, :result => "Request completed successfully"}
              else
                resp_out=resp
              end

            else
              resp_out = {:code => 400, :result => "IOT platform credentials not found"}
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
    mongo_client.audit_logger("device_remove", remote_ip, input_json, resp_out, real_ip)
    resp_out
  end


  #!5 add address to device
  #login
  #imei = newdevice_list
  #address = newdevice_list
  #newdevice_list=[{:imei=>7967843245665, :address=>"Golubeva51"}]
  #+++
  #iot platform integration completed
  def device_add_address(login, newdevice_list)
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
              credentials = mongo_client.get_iot_oceanconnect_credent(login)
              resp = {}

              if credentials[:code]==200
                imei_data = mongo_client.get_imei_info_from_db([p[:imei]])
                if imei_data[:body]!=[]
                  ans =hua_aceanconnect_connector.modify_location_iot(credentials[:body][:app_id], credentials[:body][:secret], imei_data[:body][0]["huadata"]["body"]["deviceId"], p[:address])

                  internal_func.printer_texter({:function => "device_add_address Step2", :ans => ans, :descrition=>"answer from hua IOT", :input=>{:did=>imei_data[:body][0]["huadata"]["body"]["deviceId"], :appid=>credentials[:body][:app_id], :secret=>credentials[:body][:secret], :address=>p[:address]}}, "debug")

                  p ans
                end

              end


              #########end iot platform logic#######


              resp = mongo_client.device_modify_attr_mongo(p[:imei], p[:address])
              if resp[:code]==200
                processed.append({:imei => p[:imei]})
              end
            else
              not_processed.append({:imei => p[:imei], :address => p[:address], :error => permiss})
            end
          else
            not_processed.append({:imei => p[:imei], :address => p[:address], :error => prof_name})
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
    mongo_client.audit_logger("device_add_address", remote_ip, input_json, resp_out, real_ip)
    resp_out
  end


  #6 add service by SPA
  #imei
  #profile
  #imsi
  #msisdn
  #newdevice_list=[{:imei=>7967843245665, :attributes=>{:address=>"Golubeva51", :profile=>"wqeqcqeqwev", :msisdn=>375298766719, :imsi=>25702858586756875}}]
  #+
  def add_service(login, device_list)
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
                not_processed.append({:imei => g["imei"], :description => "New profile permission error", :error => permiss2})
              end

            else
              attr = g["attributes"]
              mongo_client.device_modify_any_attr_mongo(g["imei"], attr)
              processed.append(g["imei"])
            end
          else
            not_processed.append({:imei => g["imei"], :description => "Old profile permission error", :error => permiss1})
          end

        else
          not_processed.append({:imei => g["imei"], :error => prof_name1})
        end

      end
      resp_out = {:code => 200, :result => "Request completed successfully", :body => {:imei_processed => processed, :error_list => not_processed}}

    rescue
      resp_out = {:code => 507, :result => "Unknown SDK error"}
    end
    mongo_client.audit_logger("device_remove", remote_ip, input_json, resp_out, real_ip)
    resp_out
  end


  def answ_dev_query_format_process(dev_list)
    add_functions_connector.answ_dev_query_format_process(dev_list)
  end


  def logger_to_audit_database(proc_name, src_ip, input_json, output_json, real_ip)
    mongo_client.audit_logger(proc_name, src_ip, input_json, output_json, real_ip)
  end

  #additional procedure for checking status on iot platform
  def get_info_by_imeilist_from_iot(login, imei_list)
    resp_out={}
    begin
      dev_id_list = []
      resss = {}
      data_from_db = mongo_client.get_imei_info_from_db(imei_list)
      p data_from_db
      for g in data_from_db[:body]
        dev_id_list.append(g["huadata"]["body"]["deviceId"])
      end
      credentials = mongo_client.get_iot_oceanconnect_credent(login)
      if credentials[:code]==200
        p apid = credentials[:body][:app_id]
        p secre = credentials[:body][:secret]
        resp_out = hua_aceanconnect_connector.quer_dev_query_list(apid, secre, dev_id_list)
      end
    rescue
      resp_out = {:code => "500", :message => "get_info_by_imeilist_from_iot: Something wrong", :body => {"devices" => []}}
    end
    internal_func.printer_texter(resp_out, "debug")
    resp_out
  end


  #for internal use. Add new device model
  def add_model_to_mongo(model, manufacture_id, manufacture_name, device_type, description, note)
    model = {
        model: model,
        ManufacturerID: manufacture_id,
        ManufacturerNAME: manufacture_name,
        device_type: device_type,
        description: description,
        note: note,
        created: DateTime.now
    }
    mongo_client.imei_insert_model(model)
  end

  def test()
    ddd = MongoIot.new(mongoip, mongoport, mongo_database)
    #ddd.get_profiles_by_login("test")

    ff = [131234123412341233, 131234123127341233]
    #ddd.get_imsi_info_from_db(ff)

    #p ddd.get_profile_id_by_name("1341241")
    p ddd.get_device_type_info_by_model("BGT_PPMC11")
  end

end
