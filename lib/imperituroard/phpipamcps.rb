require 'net/http'
require 'uri'
require 'json'
require 'savon'


class Pcps
  attr_accessor :wsdl, :endpoint, :namespace, :clientcps

  def initialize(wsdl, endpoint, namespace)
    @wsdl = wsdl
    @endpoint = endpoint
    @namespace = namespace
    @clientcps = Savon.client do
      ssl_verify_mode :none
      #wsdl "https://172.24.242.4:8443/ua/wsdl/UnifiedApi.wsdl"
      #endpoint "http://172.24.242.4:8080/ua/soap"
      wsdl wsdl
      endpoint endpoint
      namespace namespace
    end
  end

  def avp_attr_list(username)

    message2 = {:networkId => username}
    response = clientcps.call(:get_subscriber) do
      message(message2)
    end
    aaa = response.to_hash[:get_subscriber_response][:subscriber][:avp]
    #li = {"FRAMED-IP-ADDRESS":0,"FRAMED-NETMASK":0,"Default-Gateway":0,"VRF-ID":0,"DHCP-CLASS":0,"IPV4-UNNUMB":0,"PREFIX":0}
    li = {"FRAMED-IP-ADDRESS" => 0,
          "FRAMED-NETMASK" => 0,
          "Default-Gateway" => 0,
          "VRF-ID" => 0,
          "DHCP-CLASS" => 0,
          "IPV4-UNNUMB" => 0,
          "FRAMED-ROUTE-1" => 0}
    if !aaa.is_a?(Hash)
      for i in aaa
        if i[:code]=="FRAMED-IP-ADDRESS"
          li["FRAMED-IP-ADDRESS"]=1
        elsif i[:code]=="FRAMED-NETMASK"
          li["FRAMED-NETMASK"]=1
        elsif i[:code]=="Default-Gateway"
          li["Default-Gateway"]=1
        elsif i[:code]=="VRF-ID"
          li["VRF-ID"]=1
        elsif i[:code]=="DHCP-CLASS"
          li["DHCP-CLASS"]=1
        elsif i[:code]=="IPV4-UNNUMB"
          li["IPV4-UNNUMB"]=1
        elsif i[:code]=="FRAMED-ROUTE-1"
          li["FRAMED-ROUTE-1"]=1
        end
      end
    end
    li
  end


  #delete avp attributes from CPS
  def del_attribute(username)
    begin
      list = avp_attr_list(username)

      answer = ""

      for iti in list
        if iti[1]==1
          message2 = {
              :audit => {:id => "SOAPGW", :comment => "some procedure"},
              :networkId => username,
              :deletedAvp => [
                  {:code => iti[0]}
#                {:code => "FRAMED-NETMASK"},
              #               {:code => "Default-Gateway"},
              #                {:code => "VRF-ID"},
              #                {:code => "DHCP-CLASS"},
              #                {:code => "IPV4-UNNUMB"},
              #                {:code => "PREFIX"}
              ]
          }
          response = clientcps.call(:change_subscriber_avps) do
            message(message2)
          end
          response
          answer = response.to_hash[:change_subscriber_avps_response][:error_code]
        end
      end

    rescue
      answer = "error"
    end
    answer
  end


  def get_current_attributes(msisdn)
    message2 = {:networkId => msisdn}
    response = clientcps.call(:get_subscriber) do
      message(message2)
    end
    aaa = response.to_hash[:get_subscriber_response][:subscriber][:avp]
    p aaa
  end

  def add_attribute(attlist, username)
    message1 = {
        :audit => {:id => "SOAPGW", :comment => "some procedure"},
        :networkId => username,
        :newAvp => attlist
    }
    response = clientcps.call(:change_subscriber_avps) do
      message(message1)
    end
    response.to_hash
    answer = response.to_hash[:change_subscriber_avps_response][:error_code]
  end

  def change_attr_cps(old_msisdn, new_msisdn)

    ans = ""

    current = get_current_attributes(old_msisdn)
    attr_act = ["FRAMED-IP-ADDRESS", "FRAMED-NETMASK", "Default-Gateway", "VRF-ID", "DHCP-CLASS", "IPV4-UNNUMB", "FRAMED-ROUTE-1"]

    res_list= []
    for j in current
      if attr_act.include?(j[:code])
        res_list << j
      end
    end

    added_res = add_attribute(res_list, new_msisdn)

    if added_res == "0"
      ans = del_attribute(old_msisdn)
      p ans
    end

    if ans == "0"
      "ok"
    else
      "error"
    end
  end


end
