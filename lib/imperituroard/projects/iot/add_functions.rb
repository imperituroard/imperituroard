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
end