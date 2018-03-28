require('ost-sdk-ruby')
require "redis"
environment = 'sandbox'  # possible values sandbox / main
api_key = '...' # replace with the API Key you obtained earlier
api_secret = '...' # replace with the API Secret you obtained earlier
credentials = OSTSdk::Util::APICredentials.new(api_key, api_secret)
transactions = []
ostUsersObject = OSTSdk::Saas::Users.new(environment, credentials)
ostTransactionKindObject = OSTSdk::Saas::TransactionKind.new(environment, credentials) # initializes a TransactionKind object


redis = Redis.new
redis.flushall
while (true)
    page = 1
    users_list = []
    while page
        sleep 0.5
        puts page
        users_list_object = ostUsersObject.list( page_no: page, order_by: "creation_time", order: "asc") # returns an object that includes the list of users

        if !users_list_object.error.nil?
            puts users_list_object.http_code
            puts users_list_object.error_message
            puts users_list_object.error_data
            exit
        end
        users_list.concat users_list_object.data["economy_users"]
        nextpage = users_list_object.data['meta']['next_page_payload']['page_no']
        page=nextpage
    end

    for user in users_list
        if (user["token_balance"].to_f<20)
            redis.del user["uuid"]
        else
            redis.set(user["uuid"], user.to_json)
        end
    end
    sleep(60)
end