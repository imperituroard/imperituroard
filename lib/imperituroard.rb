$LOAD_PATH.unshift File.expand_path("../projects/iot", __dir__)
$LOAD_PATH.unshift File.expand_path("../projects/wttx", __dir__)

require "imperituroard/version"
require "imperituroard/phpipamdb"
require "imperituroard/phpipamcps"
require "imperituroard/projects/iot/mongoconnector"
require "imperituroard/projects/iot/hua_oceanconnect_adapter"

module Imperituroard
  class Error < StandardError; end

  def initialize()
  end

  def hhh(jjj)
    p jjj
  end
  # Your code goes here...
end

module Phpipam
  def test(ggg)
    p ggg
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
  include Phpipam
end

class Iot
  attr_accessor :mongoip, :mongoport, :iotip, :iottoken, :database, :iotplatform_ip, :iotplatform_port

  def initialize(mongoip, mongoport, iotip, database, iotplatform_ip, iotplatform_port)
    @mongoip = mongoip
    @mongoport = mongoport
    @iotip = iotip
    @database = database
    @iotplatform_ip = iotplatform_ip
    @iotplatform_port = iotplatform_port
  end

  def test()
    ddd = MongoIot.new(mongoip, mongoport, iotip, database)
    ddd.ttt
  end

  def testhua()
    ddd1 = HuaIot.new(iotplatform_ip, iotplatform_port, "", "")
    ddd1.test

  end



end
