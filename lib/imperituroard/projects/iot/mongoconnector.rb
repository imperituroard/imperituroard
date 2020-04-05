require 'mongo'

#class for communication with mongo database for iot API
class MongoIot

  attr_accessor :mongoip, :mongoport, :client, :database

  def initialize(mongoip, mongoport, iotip, database)
    @database = database
    @mongoip = mongoip
    @mongoport = mongoport
    @iotip = iotip
    client_host = [mongoip + ":" + mongoport]
    @client = Mongo::Client.new(client_host, :database => database)

  end

  def ttt
    p "111111"
    begin
      puts(client.cluster.inspect)
      puts
      puts('Collection Names: ')
      puts(client.database.collection_names)
      puts('Connected!')
      collection = client[:audit]
      doc = {
          name: 'Steve',
          hobbies: [ 'hiking', 'tennis', 'fly fishing' ],
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