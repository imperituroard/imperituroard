require "imperituroard/version"
require "imperituroard/phpipamdb"
require "imperituroard/phpipamcps"

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


