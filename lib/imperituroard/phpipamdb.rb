require 'mysql2'



class Pdb

  attr_accessor :database, :username, :password, :table, :ip, :port, :client
  def initialize(database, username, password, ip, port)
    @database = database
    @username = username
    @password = password
    @ip = ip
    @port = port
    @client = Mysql2::Client.new(:host => ip, :username => username, :password => password)
  end

  def check_if_msisdn_exists(msisdn, table)

    req1 = "use " + database
    req2 = "SELECT count(*) FROM " + table + " where hostname='#{msisdn}' or dns_name='#{msisdn}'"
    client.query(req1, :cast => false)
    client.query(req2, :as => :array).each do |row|
    #client.close
    res = row [0]
      return res
      #return number of existed ip addresses in database
    end
  end

  def update_database_rewrite_msisdn(msisdn_old, msisdn_new)
    begin
    req1 = "use " + database
    req2 = "UPDATE ipaddresses set hostname='#{msisdn_new}', dns_name='#{msisdn_new}' where hostname='#{msisdn_old}' or dns_name='#{msisdn_old}'"
    req3 = "UPDATE subnets set hostname='#{msisdn_new}' where hostname='#{msisdn_old}'"
    client.query(req1, :cast => false)
    client.query(req2, :cast => false)
    client.query(req3, :cast => false)
    "success"
    rescue
      "dbfailed"
    end

  end

end
