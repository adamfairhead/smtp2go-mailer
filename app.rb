require 'rubygems'
require 'sinatra'
require 'pony'
require 'aws/s3'

def authenticated
  (params[:key] == SECRET_KEY)
end

get '/' do
  "SMTP2GO site mailer application"
end

get '/job-new' do
  erb :job_new
end

post '/job-post' do
  response.headers['Access-Control-Allow-Origin'] = '*'
  response.headers['Access-Control-Allow-Methods'] = 'POST, PUT, DELETE, GET, OPTIONS'
  response.headers['Access-Control-Request-Method'] = '*'
  response.headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'

  file       = params[:file][:tempfile]
  filename   = params[:file][:filename]

  AWS::S3::DEFAULT_HOST = "#{ENV['AWS_ENDPOINT']}.amazonaws.com"

  AWS::S3::Base.establish_connection!(
    :access_key_id     => ENV['AWS_KEY'],
    :secret_access_key => ENV['AWS_SECRET']
  )

  AWS::S3::S3Object.store(
    filename,
    open(file.path),
    ENV['AWS_BUCKET'],
    :access => :public_read
  )

  AWS::S3::S3Object.rename filename, "#{Time.now.strftime("%d-%m-%Y%H:%M")}-#{filename}", ENV['AWS_BUCKET']

  s3url = "https://#{ENV['AWS_BUCKET']}.s3.amazonaws.com/#{Time.now.strftime("%d-%m-%Y%H:%M")}-#{filename}" 

  #if authenticated
    recipient = "charlie@smtp2go.com"
    name = params[:name]
    email = params[:email]
    phone = params[:phone]
    job = params[:job]
    cover = params[:cover]

    Pony.mail({
      :to => "#{recipient}",
      :from => "#{email}",
      :subject => "Application for “#{job}” from #{name}",
      :body => "Name: #{name}\n\nJob applied for: #{job}\n\nEmail address: #{email}\n\nPhone number: #{phone}\n\nCover letter:\n#{cover}\n\nResume: #{s3url}",
      :via => :smtp,
      :via_options => {
        :address        => "#{ENV['SMTP_ADDRESS']}",
        :port           => "#{ENV['SMTP_PORT']}",
        :user_name      => "#{ENV['SMTP_USERNAME']}",
        :password       => "#{ENV['SMTP_PASSWORD']}",
        :authentication => :login
      }
    })
    
    Pony.mail({
      :to => "#{email}",
      :from => "#{recipient}",
      :subject => "Thanks for applying!",
      :body => "Hi #{name},\n\nThanks for applying to be a part of the SMTP2GO team. This is just a quick email to let you know we've received your application, and we'll be reviewing it soon.\n\nIf you have any questions, feel free to reply to this email and let me know what's on your mind.\n\nThanks!\n\n---\nCharlie Abrahamson\nSMTP2GO Founder",
      :via => :smtp,
      :via_options => {
        :address        => "#{ENV['SMTP_ADDRESS']}",
        :port           => "#{ENV['SMTP_PORT']}",
        :user_name      => "#{ENV['SMTP_USERNAME']}",
        :password       => "#{ENV['SMTP_PASSWORD']}",
        :authentication => :login
      }
    })
  #end

  erb :job_sent

  halt 200
end
