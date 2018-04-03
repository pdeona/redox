module Redox
  # Redox API client
  class Client
    # Instantiates a new Redox connection object
    #
    # @param [String] api_key API key for the connection
    # @param [String] secret API secret for the connection
    # @param [Hash] source source information
    # @param [Array<Hash>] destinations list of destinations
    # @param [Boolean] test whether to use test mode
    # @example
    #   redox = Redox::Redox.new(
    #     api_key: ENV['REDOX_KEY'],
    #     secret: ENV['REDOX_SECRET'],
    #     source: source,
    #     destinations: destinations,
    #     test: true
    #   )
    def initialize(source:, destinations:, test: true)
      return unless access_token

      @source = source
      @destinations = destinations
      @test = test
    end

    # Send NewPatient message
    #
    # @param [Hash] patient_params data to send in the Patient JSON object
    # @return [Hash] parsed response object
    # @example
    #   Redox::Redox.new(*connection_params).add_patient(
    #     Identifiers: [],
    #     Demographics: {
    #       FirstName: 'Joe'
    #     }
    #   )
    def add_patient(patient_params)
      patient_request = Net::HTTP::Post.new('/endpoint', auth_header)
      request_body = request_meta(
        data_model: 'PatientAdmin', event_type: 'NewPatient'
      ).merge(Patient: patient_params)
      patient_request.body = request_body.to_json
      response = connection.request(patient_request)

      JSON.parse(response.body)
    end

    private

    attr_reader :source, :destinations, :test

    def access_token
      return @access_token if @access_token

      response = connection.request(login_request)
      code = response.code.to_i
      body = JSON.parse(response.body)
      if code >= 200
        @refresh_token = body['refreshToken']
        @access_token = body['accessToken']
        return
      end
      raise TokenError, 'Unable to obtain token.'
    end

    def connection
      return @connection if @connection

      http = Net::HTTP.new(API_URL.host, API_URL.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.verify_depth = 5

      @connection = http
    end

    def auth_header
      {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json'
      }
    end

    def request_meta(data_model:, event_type:)
      {
        Meta: {
          DataModel: data_model,
          EventType: event_type,
          EventDateTime: Time.now.to_json,
          Test: @test,
          Source: @source,
          Destinations: @destinations
        }
      }
    end

    def login_request
      req_url = @refresh_token ? 'auth/refreshToken' : '/auth/authenticate'
      req = Net::HTTP::Post.new(req_url, 'Content-Type' => 'application/json')
      req_body = { apiKey: Redox.api_key }
      if @refresh_token
        req_body[:refreshToken] = @refresh_token
      else
        req_body[:secret] = Redox.secret
      end
      req.body = req_body.to_json
      req
    end
  end
end
