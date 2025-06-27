require 'sinatra'
require 'nokogiri'
require 'pg'
require 'dotenv'
require 'openssl'
require 'securerandom'
require 'sinatra/cross_origin'

configure do
  enable :cross_origin
end

before do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
end

options '*' do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
  response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
  200
end

# Load environment variables
Dotenv.load

# Setting up the PostgreSQL database
DB = PG.connect(
  dbname: ENV['POSTGRESQL_DATABASE'],
  host: ENV['POSTGRESQL_HOST'],
  port: ENV['POSTGRESQL_PORT'],
  user: ENV['POSTGRESQL_USER'],
  password: ENV['POSTGRESQL_PASSWORD']
)

# Create the users table if it does not exist
def create_table
  query = <<-SQL
    CREATE TABLE IF NOT EXISTS "user" (
      id UUID PRIMARY KEY,
      username VARCHAR(80) UNIQUE NOT NULL,
      password VARCHAR(200) NOT NULL,
      first_name VARCHAR(100) NOT NULL,
      last_name VARCHAR(100) NOT NULL,
      dni VARCHAR(20) UNIQUE NOT NULL,
      email VARCHAR(120) UNIQUE NOT NULL,
      city VARCHAR(100) NOT NULL
    );
  SQL

  DB.exec(query)
end

# Function to store the user in the databaseaaa
def store_user(username, hashed_password, first_name, last_name, dni, email, city)
  user_id = SecureRandom.uuid
  query = <<-SQL
    INSERT INTO "user" (id, username, password, first_name, last_name, dni, email, city)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    RETURNING id;
  SQL
  result = DB.exec_params(query, [user_id, username, hashed_password, first_name, last_name, dni, email, city])
  return result[0]['id']
end

# Function to encrypt the password using PBKDF2
def hash_password(password)
  salt = 'salt'  # In a real environment, use a random and unique salt per user
  iterations = 1000
  key_length = 64

  # We perform the PBKDF2 hash with the SHA256 algorithm
  hashed_password = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, iterations, key_length, 'sha256')
  
  # We convert the result to hexadecimal format to store in the database
  hashed_password.unpack1('H*')
end

# Route to process SOAP requests
post '/register' do
  request.body.rewind
  request_payload = request.body.read

  # puts "🔍 Received SOAP Request:\n#{request_payload}"  # 👉 This will display the received XML

  if request_payload.empty?
    return "No SOAP request body found."
  end

  # Parse the XML body of the SOAP request
  begin
    doc = Nokogiri::XML(request_payload)
    # Extract values ​​from the XML (using XPath to navigate the XML)
    namespace = { 'user' => 'http://example.com/user' }

    username = doc.xpath('//user:username', namespace).text.strip
    password = doc.xpath('//user:password', namespace).text.strip
    first_name = doc.xpath('//user:first_name', namespace).text.strip
    last_name = doc.xpath('//user:last_name', namespace).text.strip
    dni = doc.xpath('//user:dni', namespace).text.strip
    email = doc.xpath('//user:email', namespace).text.strip
    city = doc.xpath('//user:city', namespace).text.strip

    # Encrypt the password before storing it
    hashed_password = hash_password(password)

    # Store the user in the database with the encrypted password
    user_id = store_user(username, hashed_password, first_name, last_name, dni, email, city)

    # Respond with a SOAP success message
    content_type :xml
    "<soapenv:Envelope xmlns:soapenv='http://schemas.xmlsoap.org/soap/envelope/' xmlns:us='http://example.com/userservice'>
      <soapenv:Header/>
      <soapenv:Body>
        <us:registerUserResponse>
          <us:message>User registered successfully</us:message>
          <us:id>#{user_id}</us:id>
        </us:registerUserResponse>
      </soapenv:Body>
    </soapenv:Envelope>"
  rescue StandardError => e
    status 500
    "Error processing SOAP request: #{e.message}"
  end
end

# Initialization
create_table

# Start the server
set :bind, '0.0.0.0'
set :port, 5002
puts "User SOAP service is running on port 5002..."