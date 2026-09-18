require 'net/http'
require 'uri'
require 'json'
require 'openssl'

class OmniWalletClient
  attr_reader :base_url, :device_key, :read_timeout, :open_timeout

  def initialize(base_url: nil, device_key: nil, read_timeout: 5, open_timeout: 3)
    @base_url = (base_url || ENV.fetch('OMNI_WALLET_URL', 'http://localhost:3000')).chomp('/')
    @device_key = device_key || ENV.fetch('POS_DEVICE_KEY', 'default-device-key')
    @read_timeout = read_timeout
    @open_timeout = open_timeout
  end

  def lookup_customer(phone:)
    get_request("/v1/customers/#{URI.encode_www_form_component(phone)}")
  end

  def verify_pin(customer_id:, pin:)
    post_request("/v1/customers/#{customer_id}/verify_pin", { pin: pin })
  end

  def debit_wallet(customer_id:, merchant_id:, amount_cents:, pin:, idempotency_key:, order_id:)
    payload = {
      customer_id: customer_id,
      merchant_id: merchant_id,
      amount: amount_cents,
      pin: pin,
      order_id: order_id
    }
    headers = {
      'X-Idempotency-Key' => idempotency_key.to_s
    }
    post_request('/v1/transfers/purchase', payload, headers)
  end

  def get_tender_by_key(idempotency_key:)
    get_request("/v1/tenders/by-key/#{idempotency_key}")
  end

  private

  def get_request(path, headers = {})
    uri = URI.parse("#{base_url}#{path}")
    http = build_http(uri)
    req = Net::HTTP::Get.new(uri.request_uri)

    timestamp = (headers['X-Device-Timestamp'] || Time.current.to_i).to_s
    nonce = (headers['X-Device-Nonce'] || SecureRandom.hex(16)).to_s
    signature = generate_signature(req.method, path, '', timestamp: timestamp, nonce: nonce)

    auth_headers = {
      'X-Device-Signature' => signature,
      'X-Device-Timestamp' => timestamp,
      'X-Device-Nonce' => nonce
    }
    apply_headers(req, headers.merge(auth_headers))

    execute_request(http, req)
  end

  def post_request(path, body = {}, headers = {})
    uri = URI.parse("#{base_url}#{path}")
    http = build_http(uri)
    req = Net::HTTP::Post.new(uri.request_uri)
    req['Content-Type'] = 'application/json'
    req.body = body.to_json

    timestamp = (headers['X-Device-Timestamp'] || Time.current.to_i).to_s
    nonce = (headers['X-Device-Nonce'] || SecureRandom.hex(16)).to_s
    signature = generate_signature(req.method, path, req.body, timestamp: timestamp, nonce: nonce)

    auth_headers = {
      'X-Device-Signature' => signature,
      'X-Device-Timestamp' => timestamp,
      'X-Device-Nonce' => nonce
    }
    apply_headers(req, headers.merge(auth_headers))

    execute_request(http, req)
  end

  def build_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = read_timeout
    http.open_timeout = open_timeout
    http
  end

  def apply_headers(req, headers)
    headers.each { |k, v| req[k] = v.to_s }
  end

  def generate_signature(method, path, body, timestamp: nil, nonce: nil)
    timestamp = (timestamp || Time.current.to_i).to_s
    nonce = (nonce || SecureRandom.hex(16)).to_s
    data = "#{method}:#{path}:#{body}:#{timestamp}:#{nonce}"
    OpenSSL::HMAC.hexdigest('SHA256', device_key, data)
  end

  def execute_request(http, req)
    res = http.request(req)
    parsed = JSON.parse(res.body) rescue {}

    if res.is_a?(Net::HTTPSuccess)
      parsed.is_a?(Hash) ? parsed.with_indifferent_access.merge(success: true) : { success: true, data: parsed }
    else
      { success: false, status: :error, code: res.code.to_i, error: parsed['error'] || res.message }
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
    { success: false, status: :unknown, error: e.message }
  rescue StandardError => e
    { success: false, status: :failed, error: e.message }
  end
end
