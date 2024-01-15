module Fcmpush
  class Configuration
    attr_accessor :scope, :json_key_io, :server_key

    def initialize
      @scope = ['https://www.googleapis.com/auth/firebase.messaging']

      # set file path
      @json_key_io = nil

      # Or Environment Variable
      # ENV['GOOGLE_ACCOUNT_TYPE'] = 'service_account'
      # ENV['GOOGLE_CLIENT_ID'] = '000000000000000000000'
      # ENV['GOOGLE_CLIENT_EMAIL'] = 'xxxx@xxxx.iam.gserviceaccount.com'
      # ENV['GOOGLE_PRIVATE_KEY'] = '-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n'

      # regacy auth
      # @deprecated TODO: remove this next version
      @server_key = ENV['FCM_SERVER_KEY']
      if @server_key
        warn '[DEPRECATION] `FCM_SERVER_KEY` environment variable, also @server_key is deprecated. This attribute will be removed next version.'
      end

    end
  end
end
