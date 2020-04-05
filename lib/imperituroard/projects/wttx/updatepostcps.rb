require 'net/http'
require 'uri'
require 'rexml/document'


class StateWTTX

  def update_statuswttx(imsi, imei)

    doc = REXML::Document.new
    #doc.context[:attribute_quote] = :quote  # <-- Set double-quote as the attribute value delimiter
    root = doc.add_element('row')

    attr1 = root.add_element('key')
    attr1.add_attribute('code', 'imsi')
    attr1.add_attribute('value', imsi)

    attr2 = root.add_element('field')
    attr2.add_attribute('code', 'imei')
    attr2.add_attribute('value', imei)

    attr3 = root.add_element('field')
    attr3.add_attribute('code', 'status')
    attr3.add_attribute('value', 'TRUE')

    xmlout = ""
    doc.write xmlout
    p xmlout

    url_string = "http://172.24.220.77:8080/custrefdata/wttx/_update"
    xml_string = xmlout
    uri = URI.parse url_string
    request = Net::HTTP::Post.new uri.path
    p request.body = xml_string
    request.content_type = 'application/xml'
    p  response = Net::HTTP.new(uri.host, uri.port).start { |http| http.request request }
    p response.body
  end


  def getrest_cps(imsi)

    url = "http://172.24.220.77:8080/custrefdata/wttx/_query?imsi=#{imsi}"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    p content = response.body
    p resultcode = response.to_s.include?("OK")
    #Rails.logger = Logger.new(STDOUT)
    #logger.info "WTTX service getrestCPS result code: #{response.to_s}"
    #logger.info "WTTX service getrestCPS soap body: #{content.to_s}"



    if resultcode = false
      "false"
    else
      regimsi = /<field code=\"imsi\" value=\"([0-9]{10,15})\"/
      regimei = /<field code=\"imei\" value=\"([0-9]{10,17})\"/

      m1 = regimsi.match(content)
      m2 = regimei.match(content)
      imsi = m1[1]
      imei = m2[1]

      res = resultcode.to_s + " " + imsi + " " + imei
      p res
      return res
    end

  end

end