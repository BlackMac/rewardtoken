require('ost-sdk-ruby')
require "redis"
environment = 'sandbox'  # possible values sandbox / main
api_key = '...' # replace with the API Key you obtained earlier
api_secret = '...' # replace with the API Secret you obtained earlier
credentials = OSTSdk::Util::APICredentials.new(api_key, api_secret)
transactions = []
ostUsersObject = OSTSdk::Saas::Users.new(environment, credentials)
ostTransactionKindObject = OSTSdk::Saas::TransactionKind.new(environment, credentials) # initializes a TransactionKind object

def log(data)
    t = Thread.new do
        uri = URI("http://logs-01.loggly.com/inputs/.../tag/ost/")
        req = Net::HTTP::Post.new(uri)
        req['content-type'] = "content-type:application/x-www-form-urlencoded"
        req.body = data.to_json
        res = Net::HTTP.start(uri.hostname, uri.port) {|http|
        http.request(req)
        }
    end
end

def logtrans(kind, from, to, uuid)
    data = {
        type:"trasaction",
        kind: kind,
        to: to,
        from: from,
        tauuid: uuid
    }
    log data
    puts kind +" ["+uuid+"] " + ": " + from + " => " + to
end

def logerr(message, data)
    data = {
        type:"error",
        message: message,
        data: data
    }
    log data
    puts message
end


redis = Redis.new

while (true)
    begin  # "try" block
        r1 = redis.randomkey()
        r2 = redis.randomkey()
        if r1 == r2
            next
        end
        if r1.nil?
            next
        end
        if r2.nil?
            next
        end
        u1 = JSON.parse(redis.get(redis.randomkey()))
        u2 = JSON.parse(redis.get(redis.randomkey()))
        if u1["uuid"] == u2["uuid"]
            next
        end
        kind = "tiny"
        b1 = u1["token_balance"].to_f
        b2 = u2["token_balance"].to_f
        if (b1 >= 0.1)
            u1["token_balance"] = (b1-0.1).to_s
            u2["token_balance"] = (b2+0.1).to_s
            kind = "tiny"
        end
        if (b1 >= 1)
            u1["token_balance"] = (b1-1).to_s
            u2["token_balance"] = (b2+1).to_s
            kind = "small"
        end
        if (b1 >= 10)
            u1["token_balance"] = (b1-10).to_s
            u2["token_balance"] = (b2+10).to_s
            kind = "medium"
        end
        if (b1 >= 20)
            u1["token_balance"] = (b1-20).to_s
            u2["token_balance"] = (b2+20).to_s
            kind = "large"
        end
        if (b1 >= 100)
            u1["token_balance"] = (b1-100).to_s
            u2["token_balance"] = (b2+100).to_s
            kind = "huge"
        end

        u1["token_balance"] = (b1-0.1).to_s
        u2["token_balance"] = (b2+0.1).to_s
        redis.set(u1["uuid"], u1.to_json)
        redis.set(u2["uuid"], u2.to_json)

        ta = ostTransactionKindObject.execute(from_uuid: u1["uuid"], to_uuid: u2["uuid"], transaction_kind: kind)

        if !ta.error.nil?
            logerr ta.error_message, ta.error_data
        else
            logtrans kind, u1["uuid"], u2["uuid"], ta.data["transaction_uuid"]
        end
    rescue # optionally: `rescue Exception => ex`
        puts 'I am rescued.'
        redis = Redis.new
    ensure # will always get executed

    end
end