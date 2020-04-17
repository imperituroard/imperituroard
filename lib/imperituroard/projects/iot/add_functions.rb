require 'net/http'
require 'net/https'
require 'json'


class AdditionalFunc

  attr_accessor :telegram_api_url, :telegram_chat_id

  def initialize(telegram_api_url, telegram_chat_id)
    @telegram_api_url = telegram_api_url
    @telegram_chat_id = telegram_chat_id

  end

  #procedure for send log to telegram chat
  def telegram_message(message)
    begin
      uri = URI.parse(telegram_api_url)
      https_connector = Net::HTTP.new(uri.host, uri.port)
      https_connector.use_ssl = true
      data = {chat_id: telegram_chat_id, text: message}
      request_mess = Net::HTTP::Post.new(uri.request_uri, {'Content-Type' => 'application/json'})
      request_mess.body = data.to_json
      response_mess = https_connector.request(request_mess)
      body = response_mess.body
      return {:code => 200,
              :result => "Request completed successfully",
              :body => {:telegram_resp => JSON.parse(body.to_s),
                        :description => "Telegram message to telegram_chat_id: #{telegram_chat_id.to_s}"}}
    rescue
      return {:code => 507, :result => "Unknown SDK error"}
    end
  end


  def answ_dev_query_format_process(dev_list)
    dataaa_ok = []
    dataaa_failed = []
    final_answ = {}

    begin
      if dev_list[:approved_list]!=[]
        for i in dev_list[:approved_list][:body]
          begin
            imei =0
            imsi =0
            msisdn =0
            description ="nil"
            note ="nil"
            type ="nil"
            profile ="nil"
            address ="nil"

            if i.key?("imei")
              imei=i["imei"]
            end
            if i.key?("imsi")
              imsi=i["imsi"]
            end
            if i.key?("msisdn")
              msisdn=i["msisdn"]
            end
            if i.key?("description")
              if i["description"] == nil
                description="nil"
              else
                description=i["description"]
              end
            end
            if i.key?("note")
              if i["note"] == nil
                note="nil"
              else
                note=i["note"]
              end
            end
            if i.key?("type")
              type=i["type"]
            end
            if i.key?("profile")
              profile=i["profile"]
            end
            if i.key?("address")
              address=i["address"]
            end
            dataaa_ok.append({:imei => imei,
                              :imsi => imsi,
                              :msisdn => msisdn,
                              :description => description,
                              :note => note,
                              :type => type,
                              :profile => profile,
                              :address => address})
          rescue
            dataaa_failed.append(i[:imei])
          end
        end
      end


      begin
        for i in dev_list[:unapproved_list]
          dataaa_failed.append(i[:imei])
        end
      rescue
        nil
      end

      final_answ = {:ok => dataaa_ok, :failed => dataaa_failed}
      {:code => 200, :result => "Request completed successfully", :body => final_answ}
    rescue
      {:code => 507, :result => "Unknown SDK error", :body => {}}
    end

  end


end